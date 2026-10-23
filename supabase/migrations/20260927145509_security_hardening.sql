-- LifeLink security and consistency upgrade. No clinical rows are deleted.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create or replace function private.active_role() returns text
language sql stable security definer set search_path = '' as $$
  select p.role::text from public.profiles p
  where p.id = (select auth.uid()) and p.status = 'active';
$$;
revoke all on function private.active_role() from public, anon;
grant execute on function private.active_role() to authenticated, service_role;

create or replace function private.is_guardian(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.guardianships g where g.donor_id = auth.uid()
      and g.patient_id = target and g.status = 'approved'
  );
$$;
revoke all on function private.is_guardian(uuid) from public, anon;
grant execute on function private.is_guardian(uuid) to authenticated;

-- Replace additive permissive policies: a single USING(true) defeats restrictive alternatives.
do $$ declare p record; begin
 for p in select tablename, policyname from pg_policies
 where schemaname='public' and tablename in ('profiles','visits','lab_results','inventory','guardianships') loop
 execute format('drop policy %I on public.%I',p.policyname,p.tablename);
 end loop;
end $$;
revoke all on public.profiles, public.visits, public.lab_results, public.inventory, public.guardianships from anon, authenticated;
grant select on public.profiles, public.visits, public.lab_results, public.inventory, public.guardianships to authenticated;
grant update(full_name,phone,role,status,blood_group,medical_history) on public.profiles to authenticated;

create policy profiles_read on public.profiles for select to authenticated using (
 id = (select auth.uid()) or (select private.active_role()) in ('admin','reception','lab')
 or ((select private.active_role()) = 'donor' and private.is_guardian(id))
 or ((select private.active_role()) = 'patient' and exists (
   select 1 from public.guardianships g where g.donor_id=profiles.id and g.patient_id=(select auth.uid())
 ))
);
create policy profiles_update on public.profiles for update to authenticated
 using (id=(select auth.uid()) or (select private.active_role())='admin'
   or ((select private.active_role())='reception' and role in ('patient','donor')))
 with check (id=(select auth.uid()) or (select private.active_role())='admin'
   or ((select private.active_role())='reception' and role in ('patient','donor')));

create or replace function private.protect_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare actor text := private.active_role();
begin
 -- Server-side Admin API provisioning is the only role assignment at creation.
 if auth.uid() is null then
   if current_user in ('postgres','supabase_admin') and session_user <> 'authenticator' then return new; end if;
   raise exception 'Authentication required' using errcode='42501';
 end if;
 if actor='admin' then
   if old.id=auth.uid() and (new.role<>old.role or new.status is distinct from old.status) then
     raise exception 'Another administrator must change your own access' using errcode='42501';
   end if;
   return new;
 end if;
 if new.role<>old.role or new.blood_group is distinct from old.blood_group then
   raise exception 'Only an administrator can change roles or verified blood groups' using errcode='42501';
 end if;
 if new.status is distinct from old.status and not (
   actor='reception' and old.role in ('donor','patient') and old.status='pending' and new.status='active'
 ) then raise exception 'Not authorized to change account status' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function private.protect_profile() from public, anon, authenticated;
create trigger protect_profile_access before update on public.profiles for each row execute function private.protect_profile();

create policy visits_read on public.visits for select to authenticated using (
 (select private.active_role()) in ('admin','reception','lab') or
 ((select private.active_role()) in ('patient','donor') and (user_id=(select auth.uid()) or private.is_guardian(user_id)))
);
create policy labs_read on public.lab_results for select to authenticated using (
 (select private.active_role()) in ('admin','lab') or
 ((select private.active_role()) in ('patient','donor') and exists (select 1 from public.visits v where v.id=visit_id))
);
create policy inventory_read on public.inventory for select to authenticated using ((select private.active_role()) in ('admin','reception','lab'));
create policy guardians_read on public.guardianships for select to authenticated using (
 (select private.active_role()) in ('admin','reception') or
 ((select private.active_role()) in ('donor','patient') and ((select auth.uid()) in (donor_id,patient_id)))
);

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare requested text := new.raw_user_meta_data->>'role'; assigned public.user_role;
begin
 if new.raw_app_meta_data->>'lifelink_provisioned'='true' and new.raw_app_meta_data->>'role' in ('reception','lab') then
   assigned := (new.raw_app_meta_data->>'role')::public.user_role;
 else
   assigned := case when requested='donor' then 'donor'::public.user_role else 'patient'::public.user_role end;
 end if;
 insert into public.profiles(id,full_name,phone,role,blood_group,status,medical_history)
 values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name','New user'),150),left(new.raw_user_meta_data->>'phone',30),assigned,
   case when new.raw_user_meta_data->>'blood_group' in ('A+','A-','B+','B-','AB+','AB-','O+','O-') then (new.raw_user_meta_data->>'blood_group')::public.blood_group_type else null end,
   case when assigned in ('reception','lab') then 'active'::public.user_status else 'pending'::public.user_status end,
   new.raw_user_meta_data->'medical_history');
 return new;
end $$;
revoke all on function public.handle_new_user() from public,anon,authenticated;

-- Retire the unsafe legacy import path and anonymous privileged RPC access.
revoke all on function public.admin_import_user(text,text,text,text,text) from public,anon,authenticated;
alter function public.admin_import_user(text,text,text,text,text) set search_path = '';
create or replace function public.get_user_role() returns text language sql stable security invoker set search_path='' as $$ select private.active_role(); $$;
revoke all on function public.get_user_role() from public,anon;
grant execute on function public.get_user_role() to authenticated;

create table private.audit_events (
 id bigint generated always as identity primary key,
 actor uuid, action text not null, record_id uuid, created_at timestamptz not null default now()
);
create table private.inventory_events (
 operation_id uuid primary key, blood_group public.blood_group_type not null,
 delta_ml integer not null, actor uuid not null, created_at timestamptz not null default now()
);
revoke all on private.audit_events,private.inventory_events from public,anon,authenticated;

create or replace function private.queue_visit(payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare target public.profiles; previous public.visits; visit_id uuid := (payload->>'id')::uuid;
begin
 if private.active_role() not in ('admin','reception') or private.active_role() is null then raise exception 'Reception access required' using errcode='42501'; end if;
 select * into target from public.profiles where id=(payload->>'user_id')::uuid;
 if target.status is distinct from 'active'::public.user_status or not ((target.role='donor' and payload->>'type'='donation') or (target.role='patient' and payload->>'type'='transfusion')) then
   raise exception 'An active donor or patient matching the visit type is required' using errcode='22023';
 end if;
 if length(payload->>'token_number') not between 3 and 50 or (payload->>'created_at')::timestamptz > now()+interval '5 minutes' then raise exception 'Invalid visit details' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(visit_id::text,0));
 select * into previous from public.visits where id=visit_id;
 if found then
   if previous.user_id<>target.id or previous.type::text<>payload->>'type' or previous.token_number<>payload->>'token_number' then raise exception 'Visit ID conflict' using errcode='23505'; end if;
   return visit_id;
 end if;
 insert into public.visits(id,user_id,token_number,type,status,created_at)
 values(visit_id,target.id,payload->>'token_number',(payload->>'type')::public.visit_type,'waiting_for_lab',coalesce((payload->>'created_at')::timestamptz,now()));
 insert into private.audit_events(actor,action,record_id) values(auth.uid(),'visit_created',visit_id);
 return visit_id;
end $$;
create function public.queue_visit(payload jsonb) returns uuid language sql security invoker set search_path='' as $$ select private.queue_visit(payload); $$;

create or replace function private.complete_lab_visit(payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v public.visits; previous public.lab_results; result_id uuid := (payload->>'id')::uuid; bg public.blood_group_type; volume integer := (payload->>'prescribed_volume_ml')::integer; delta integer; field text;
begin
 if private.active_role() not in ('admin','lab') or private.active_role() is null then raise exception 'Lab access required' using errcode='42501'; end if;
 if (payload->>'conducted_by')::uuid is distinct from auth.uid() then raise exception 'Technician mismatch' using errcode='42501'; end if;
 if volume is null or volume<=0 or volume>2000 then raise exception 'Invalid recorded volume' using errcode='22023'; end if;
 foreach field in array array['hemoglobin','wbc','platelets','rbc','hematocrit','mcv','mch','mchc','ferritin'] loop
   if payload->>field is null or (payload->>field)::numeric<0 or (payload->>field)::numeric>100000 or lower(payload->>field) in ('nan','infinity','-infinity') then raise exception 'Invalid lab value' using errcode='22023'; end if;
 end loop;
 select * into v from public.visits where id=(payload->>'visit_id')::uuid for update;
 if not found then raise exception 'Visit not found' using errcode='23503'; end if;
 select * into previous from public.lab_results where visit_id=v.id;
 if found then
   if previous.id=result_id and previous.conducted_by=auth.uid()
      and previous.prescribed_volume_ml=volume
      and previous.hemoglobin=(payload->>'hemoglobin')::numeric and previous.wbc=(payload->>'wbc')::numeric
      and previous.platelets=(payload->>'platelets')::numeric and previous.rbc=(payload->>'rbc')::numeric
      and previous.hematocrit=(payload->>'hematocrit')::numeric and previous.mcv=(payload->>'mcv')::numeric
      and previous.mch=(payload->>'mch')::numeric and previous.mchc=(payload->>'mchc')::numeric and previous.ferritin=(payload->>'ferritin')::numeric
   then return result_id; end if;
   raise exception 'This visit already has different results; review the conflict' using errcode='23505';
 end if;
 if v.status='completed' then raise exception 'Visit already completed' using errcode='23505'; end if;
 select blood_group into bg from public.profiles where id=v.user_id and status='active';
 if bg is null then raise exception 'A verified blood group is required' using errcode='22023'; end if;
 delta := case when v.type='donation' then volume else -volume end;
 insert into public.inventory(blood_group,volume_ml) values(bg,0) on conflict do nothing;
 perform 1 from public.inventory where blood_group=bg for update;
 if (select volume_ml from public.inventory where blood_group=bg)+delta<0 then raise exception 'Insufficient blood stock' using errcode='22023'; end if;
 insert into public.lab_results(id,visit_id,hemoglobin,wbc,platelets,rbc,hematocrit,mcv,mch,mchc,ferritin,prescribed_volume_ml,conducted_by)
 values(result_id,v.id,(payload->>'hemoglobin')::numeric,(payload->>'wbc')::numeric,(payload->>'platelets')::numeric,(payload->>'rbc')::numeric,(payload->>'hematocrit')::numeric,(payload->>'mcv')::numeric,(payload->>'mch')::numeric,(payload->>'mchc')::numeric,(payload->>'ferritin')::numeric,volume,auth.uid());
 update public.inventory set volume_ml=volume_ml+delta,last_updated=now() where blood_group=bg;
 insert into private.inventory_events(operation_id,blood_group,delta_ml,actor) values(result_id,bg,delta,auth.uid());
 update public.visits set status='completed' where id=v.id;
 insert into private.audit_events(actor,action,record_id) values(auth.uid(),'lab_completed',v.id);
 return result_id;
end $$;
create function public.complete_lab_visit(payload jsonb) returns uuid language sql security invoker set search_path='' as $$ select private.complete_lab_visit(payload); $$;

create function private.add_stock(operation_id uuid, blood_group text, volume_ml integer) returns void
language plpgsql security definer set search_path='' as $$
declare previous private.inventory_events;
begin
 if private.active_role() not in ('admin','reception') or private.active_role() is null then raise exception 'Reception access required' using errcode='42501'; end if;
 if volume_ml is null or volume_ml<=0 or volume_ml>1000000 then raise exception 'Invalid stock volume' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(operation_id::text,1));
 select * into previous from private.inventory_events e where e.operation_id=add_stock.operation_id;
 if found then
   if previous.blood_group::text<>blood_group or previous.delta_ml<>volume_ml or previous.actor<>auth.uid() then raise exception 'Operation conflict' using errcode='23505'; end if;
   return;
 end if;
 insert into public.inventory as stock(blood_group,volume_ml,last_updated) values(blood_group::public.blood_group_type,volume_ml,now())
 on conflict on constraint inventory_pkey do update set volume_ml=stock.volume_ml+excluded.volume_ml,last_updated=now();
 insert into private.inventory_events values(operation_id,blood_group::public.blood_group_type,volume_ml,auth.uid(),now());
end $$;
create function public.add_stock(operation_id uuid,blood_group text,volume_ml integer) returns void language sql security invoker set search_path='' as $$ select private.add_stock(operation_id,blood_group,volume_ml); $$;
-- Old endpoints cannot adjust stock or bypass the idempotency ledger.
revoke all on function public.adjust_inventory(text,integer),public.adjust_inventory(public.blood_group_type,integer) from public,anon,authenticated;
alter function public.adjust_inventory(text,integer) set search_path='';
alter function public.adjust_inventory(public.blood_group_type,integer) set search_path='';

create function private.request_guardianship(request_id uuid, patient uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare existing public.guardianships;
begin
 if private.active_role() is distinct from 'donor' then raise exception 'Donor access required' using errcode='42501'; end if;
 if not exists(select 1 from public.profiles where id=patient and role='patient' and status='active') then raise exception 'Patient is unavailable' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(request_id::text,2));
 select * into existing from public.guardianships where id=request_id;
 if found then
  if existing.donor_id<>auth.uid() or existing.patient_id<>patient then raise exception 'Request conflict' using errcode='23505'; end if;
  return request_id;
 end if;
 insert into public.guardianships(id,donor_id,patient_id,status) values(request_id,auth.uid(),patient,'pending');
 return request_id;
end $$;
create function public.request_guardianship(request_id uuid,patient uuid) returns uuid language sql security invoker set search_path='' as $$ select private.request_guardianship(request_id,patient); $$;
create function private.respond_guardianship(request_id uuid,decision text) returns uuid language plpgsql security definer set search_path='' as $$
begin
 if decision not in ('approved','rejected') or decision is null then raise exception 'Invalid decision' using errcode='22023'; end if;
 if private.active_role() not in ('admin','patient') or private.active_role() is null then raise exception 'Patient approval required' using errcode='42501'; end if;
 update public.guardianships set status=decision where id=request_id and (patient_id=auth.uid() or private.active_role()='admin');
 if not found then raise exception 'Request not found or access denied' using errcode='42501'; end if;
 insert into private.audit_events(actor,action,record_id) values(auth.uid(),'guardianship_'||decision,request_id);
 return request_id;
end $$;
create function public.respond_guardianship(request_id uuid,decision text) returns uuid language sql security invoker set search_path='' as $$ select private.respond_guardianship(request_id,decision); $$;

create function private.delete_uncompleted_visit(visit_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if private.active_role() is distinct from 'admin' then raise exception 'Admin access required' using errcode='42501'; end if;
 perform 1 from public.visits where id=visit_id and status<>'completed' for update;
 if not found then raise exception 'Completed clinical records cannot be deleted here' using errcode='22023'; end if;
 delete from public.visits where id=visit_id;
 insert into private.audit_events(actor,action,record_id) values(auth.uid(),'uncompleted_visit_deleted',visit_id);
end $$;
create function public.delete_uncompleted_visit(visit_id uuid) returns void language sql security invoker set search_path='' as $$ select private.delete_uncompleted_visit(visit_id); $$;

create function private.donor_leaderboard() returns table(donor_id uuid,full_name text,total_volume bigint)
language sql stable security definer set search_path='' as $$
 select case when p.id=auth.uid() then p.id else null end,
 case when p.id=auth.uid() then 'You' else 'Community donor' end,
 sum(l.prescribed_volume_ml)::bigint
 from public.profiles p join public.visits v on v.user_id=p.id join public.lab_results l on l.visit_id=v.id
 where auth.uid() is not null and private.active_role() is not null and p.role='donor' and p.status='active' and v.type='donation' and v.status='completed'
 group by p.id order by sum(l.prescribed_volume_ml) desc limit 50;
$$;
create or replace function public.get_donor_leaderboard() returns table(donor_id uuid,full_name text,total_volume bigint)
language sql stable security invoker set search_path='' as $$ select * from private.donor_leaderboard(); $$;

create table public.app_settings (
 id boolean primary key default true check(id), operator_name text not null default 'LifeLink' check(length(operator_name) between 1 and 150),
 privacy_email text not null default '' check(length(privacy_email)<=254), country text not null default '' check(length(country)<=100),
 retention_notice text not null default 'Contact the project administrator about retention and deletion. This FYP deployment has no automatic clinical-record deletion schedule.' check(length(retention_notice)<=1500),
 updated_at timestamptz not null default now()
);
alter table public.app_settings enable row level security;
insert into public.app_settings(id) values(true);
grant select on public.app_settings to anon,authenticated;
grant update(operator_name,privacy_email,country,retention_notice,updated_at) on public.app_settings to authenticated;
create policy settings_public_read on public.app_settings for select to anon,authenticated using (true);
create policy settings_admin_update on public.app_settings for update to authenticated using ((select private.active_role())='admin') with check ((select private.active_role())='admin');

create table private.ai_usage (user_id uuid not null, day date not null, requests integer not null, last_request timestamptz not null, primary key(user_id,day));
revoke all on private.ai_usage from public,anon,authenticated;
create function private.consume_ai_quota() returns void language plpgsql security definer set search_path='' as $$
declare used integer; last_used timestamptz;
begin
 if private.active_role() not in ('donor','patient') or private.active_role() is null then raise exception 'Active donor or patient account required' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(420260927);
 delete from private.ai_usage where day<current_date-2;
 select requests,last_request into used,last_used from private.ai_usage where user_id=auth.uid() and day=current_date;
 if coalesce(used,0)>=5 or last_used>now()-interval '1 minute' or (select coalesce(sum(requests),0) from private.ai_usage where day=current_date)>=100 then raise exception 'Meal draft limit reached. Try again later.' using errcode='P0001'; end if;
 insert into private.ai_usage values(auth.uid(),current_date,1,now()) on conflict(user_id,day) do update set requests=ai_usage.requests+1,last_request=now();
end $$;
create function public.consume_ai_quota() returns void language sql security invoker set search_path='' as $$ select private.consume_ai_quota(); $$;

-- Explicit grants: no privileged API is callable anonymously.
do $$ declare fn record; begin
 for fn in select p.oid::regprocedure as signature,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='private' and p.proname in ('queue_visit','complete_lab_visit','add_stock','request_guardianship','respond_guardianship','delete_uncompleted_visit','donor_leaderboard','consume_ai_quota'))
 or (n.nspname='public' and p.proname in ('queue_visit','complete_lab_visit','add_stock','request_guardianship','respond_guardianship','delete_uncompleted_visit','get_donor_leaderboard','consume_ai_quota')) loop
 execute format('revoke all on function %s from public,anon',fn.signature);
 execute format('grant execute on function %s to authenticated',fn.signature);
 end loop;
end $$;
create index if not exists visits_user_date_idx on public.visits(user_id,created_at desc);
create index if not exists visits_queue_idx on public.visits(created_at) where status='waiting_for_lab';
create index if not exists guardianships_donor_status_idx on public.guardianships(donor_id,status);
create index if not exists guardianships_patient_idx on public.guardianships(patient_id);
create index if not exists lab_results_technician_idx on public.lab_results(conducted_by);
