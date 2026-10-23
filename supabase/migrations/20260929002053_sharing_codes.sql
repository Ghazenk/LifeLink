create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare requested text := new.raw_user_meta_data->>'role'; assigned public.user_role;
begin
 if new.raw_app_meta_data->>'lifelink_provisioned'='true' and new.raw_app_meta_data->>'role' in ('reception','lab') then
   assigned := (new.raw_app_meta_data->>'role')::public.user_role;
 else
   assigned := case when requested in ('donor','caregiver') then requested::public.user_role else 'patient'::public.user_role end;
 end if;
 insert into public.profiles(id,full_name,phone,role,blood_group,status,medical_history)
 values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name','New user'),150),left(new.raw_user_meta_data->>'phone',30),assigned,
   case when new.raw_user_meta_data->>'blood_group' in ('A+','A-','B+','B-','AB+','AB-','O+','O-') then (new.raw_user_meta_data->>'blood_group')::public.blood_group_type else null end,
   case when assigned in ('reception','lab') then 'active'::public.user_status else 'pending'::public.user_status end,
   new.raw_user_meta_data->'medical_history');
 return new;
end $$;
revoke all on function public.handle_new_user() from public,anon,authenticated;


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
   actor='reception' and old.role in ('donor','patient','caregiver') and old.status='pending' and new.status='active'
 ) then raise exception 'Not authorized to change account status' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function private.protect_profile() from public, anon, authenticated;

drop policy profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (
 id=(select auth.uid()) or (select private.active_role()) in ('admin','reception','lab')
 or ((select private.active_role()) in ('donor','caregiver') and private.is_guardian(id))
 or ((select private.active_role())='patient' and exists(select 1 from public.guardianships g where g.donor_id=profiles.id and g.patient_id=(select auth.uid())))
);
drop policy profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
 using(id=(select auth.uid()) or (select private.active_role())='admin' or ((select private.active_role())='reception' and role in ('patient','donor','caregiver')))
 with check(id=(select auth.uid()) or (select private.active_role())='admin' or ((select private.active_role())='reception' and role in ('patient','donor','caregiver')));
drop policy visits_read on public.visits;
create policy visits_read on public.visits for select to authenticated using (
 (select private.active_role()) in ('admin','reception','lab') or
 ((select private.active_role()) in ('patient','donor','caregiver') and (user_id=(select auth.uid()) or private.is_guardian(user_id)))
);
drop policy labs_read on public.lab_results;
create policy labs_read on public.lab_results for select to authenticated using (
 (select private.active_role()) in ('admin','lab') or
 ((select private.active_role()) in ('patient','donor','caregiver') and exists(select 1 from public.visits v where v.id=visit_id))
);
drop policy guardians_read on public.guardianships;
create policy guardians_read on public.guardianships for select to authenticated using (
 (select private.active_role()) in ('admin','reception') or
 ((select private.active_role()) in ('donor','patient','caregiver') and (select auth.uid()) in (donor_id,patient_id))
);

create table private.share_codes (
 owner_id uuid not null references auth.users(id) on delete cascade,
 purpose text not null check(purpose in ('guardian','checkin')),
 code_hash bytea not null unique, expires_at timestamptz not null,
 created_at timestamptz not null default now(),
 consumed_by uuid references auth.users(id) on delete set null,
 consumed_at timestamptz, request_id uuid,
 primary key(owner_id,purpose)
);
create table private.share_attempts (
 actor_id uuid primary key references auth.users(id) on delete cascade,
 window_start timestamptz not null, attempts integer not null
);
alter table private.share_codes enable row level security;
alter table private.share_attempts enable row level security;
revoke all on private.share_codes,private.share_attempts from public,anon,authenticated;

create function private.create_share_code(purpose text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); actor_role text:=private.active_role(); raw text; prefix text; expires timestamptz:=now()+interval '15 minutes';
begin
 if actor is null or actor_role is null then raise exception 'Sign in with an active account' using errcode='42501'; end if;
 if purpose is null or purpose not in ('guardian','checkin') then raise exception 'Invalid purpose' using errcode='22023'; end if;
 if (purpose='guardian' and actor_role<>'patient') or (purpose='checkin' and actor_role not in ('patient','donor')) then raise exception 'Not allowed' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text||purpose,51));
 if exists(select 1 from private.share_codes c where c.owner_id=actor and c.purpose=create_share_code.purpose and c.created_at>now()-interval '5 seconds') then raise exception 'Wait a few seconds before generating another code' using errcode='22023'; end if;
 raw:=upper(encode(extensions.gen_random_bytes(6),'hex'));
 prefix:=case when purpose='guardian' then 'G' else 'C' end;
 insert into private.share_codes(owner_id,purpose,code_hash,expires_at)
 values(actor,purpose,extensions.digest('LL'||prefix||raw,'sha256'),expires)
 on conflict on constraint share_codes_pkey do update set code_hash=excluded.code_hash,expires_at=excluded.expires_at,created_at=now(),consumed_by=null,consumed_at=null,request_id=null;
 return jsonb_build_object('code','LL-'||prefix||'-'||substr(raw,1,4)||'-'||substr(raw,5,4)||'-'||substr(raw,9,4),'expires_at',expires);
end $$;
create function public.create_share_code(purpose text) returns jsonb language sql security invoker set search_path='' as $$ select private.create_share_code(purpose); $$;

create function private.revoke_share_code(purpose text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or private.active_role() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 delete from private.share_codes c where c.owner_id=auth.uid() and c.purpose=revoke_share_code.purpose;
end $$;
create function public.revoke_share_code(purpose text) returns void language sql security invoker set search_path='' as $$ select private.revoke_share_code(purpose); $$;

create function private.redeem_share_code(code text,purpose text) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); actor_role text:=private.active_role(); clean text; item private.share_codes; n integer; request uuid; state text; person public.profiles;
begin
 if actor is null or actor_role is null then raise exception 'Sign in with an active account' using errcode='42501'; end if;
 if purpose is null or purpose not in ('guardian','checkin') then raise exception 'Invalid purpose' using errcode='22023'; end if;
 if (purpose='guardian' and actor_role not in ('donor','caregiver')) or (purpose='checkin' and actor_role not in ('reception','admin')) then raise exception 'Not allowed to use this code' using errcode='42501'; end if;
 -- Return rejected attempts rather than raise, so the rate counter commits.
 insert into private.share_attempts(actor_id,window_start,attempts) values(actor,now(),1)
 on conflict(actor_id) do update set
 attempts=case when share_attempts.window_start<now()-interval '15 minutes' then 1 else share_attempts.attempts+1 end,
 window_start=case when share_attempts.window_start<now()-interval '15 minutes' then now() else share_attempts.window_start end
 returning attempts into n;
 if n>(case when purpose='checkin' then 200 else 10 end) then return jsonb_build_object('ok',false,'message','Too many attempts. Wait 15 minutes before trying again.'); end if;
 if code is null or length(code)>80 then return jsonb_build_object('ok',false,'message','Code unavailable. Ask for a new code.'); end if;
 clean:=regexp_replace(upper(code),'[-[:space:]]','','g');
 if clean !~ ('^LL'||case when purpose='guardian' then 'G' else 'C' end||'[0-9A-F]{12}$') then return jsonb_build_object('ok',false,'message','Code unavailable. Ask for a new code.'); end if;
 select * into item from private.share_codes c where c.code_hash=extensions.digest(clean,'sha256') and c.purpose=redeem_share_code.purpose for update;
 if not found or item.expires_at<=now() or item.owner_id=actor or (item.consumed_at is not null and item.consumed_by is distinct from actor) then
   return jsonb_build_object('ok',false,'message','Code unavailable. Ask for a new code.');
 end if;
 select * into person from public.profiles p where p.id=item.owner_id and p.status='active';
 if not found then return jsonb_build_object('ok',false,'message','Code unavailable. Ask for a new code.'); end if;
 if purpose='guardian' then
   if person.role<>'patient' then return jsonb_build_object('ok',false,'message','Code unavailable. Ask for a new code.'); end if;
   if item.consumed_at is not null then
     select g.id,g.status into request,state from public.guardianships g where g.id=item.request_id and g.donor_id=actor;
     return jsonb_build_object('ok',true,'request_id',request,'status',state);
   end if;
   insert into public.guardianships(id,donor_id,patient_id,status) values(gen_random_uuid(),actor,item.owner_id,'pending')
   on conflict(donor_id,patient_id) do update set status=case when guardianships.status='rejected' then 'pending' else guardianships.status end
   returning id,status into request,state;
   update private.share_codes c set consumed_by=actor,consumed_at=now(),request_id=request where c.owner_id=item.owner_id and c.purpose=redeem_share_code.purpose;
   insert into private.audit_events(actor,action,record_id) values(actor,'guardian_code_request',request);
   return jsonb_build_object('ok',true,'request_id',request,'status',state);
 end if;
 if person.role not in ('patient','donor') then return jsonb_build_object('ok',false,'message','Code unavailable. Ask for a new code.'); end if;
 update private.share_codes c set consumed_by=actor,consumed_at=coalesce(c.consumed_at,now()) where c.owner_id=item.owner_id and c.purpose=redeem_share_code.purpose;
 return jsonb_build_object('ok',true,'profile',jsonb_build_object('id',person.id,'full_name',person.full_name,'role',person.role,'blood_group',person.blood_group));
end $$;
create function public.redeem_share_code(code text,purpose text) returns jsonb language sql security invoker set search_path='' as $$ select private.redeem_share_code(code,purpose); $$;

-- UUID-only creation would bypass the invitation and guessing limit.
revoke execute on function public.request_guardianship(uuid,uuid),private.request_guardianship(uuid,uuid) from public,anon,authenticated;
-- The existing response RPC also permits a patient to revoke an approved link by rejecting it.
do $$ declare f record; begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in ('public','private') and p.proname in ('create_share_code','redeem_share_code','revoke_share_code') loop
 execute format('revoke all on function %s from public,anon',f.signature);
 execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;
