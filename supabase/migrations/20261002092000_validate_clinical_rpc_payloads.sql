-- Reject unknown fields and wrong JSON types in RPC calls, including direct calls
-- to private functions by authenticated clients.
create or replace function private.queue_visit(payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare target public.profiles; previous public.visits; visit_id uuid := (payload->>'id')::uuid;
begin
 if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>2048 then raise exception 'Invalid visit payload' using errcode='22023'; end if;
 if (select count(*) from jsonb_object_keys(payload))<>5 or exists(
   select 1 from jsonb_object_keys(payload) as f(key)
   where f.key not in ('id','user_id','type','token_number','created_at')
 ) or exists(
   select 1 from jsonb_each(payload) as f
   where jsonb_typeof(f.value)<>'string'
 ) or payload->>'token_number' ~ '[[:cntrl:]<>]' then
   raise exception 'Invalid visit payload' using errcode='22023';
 end if;
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

create or replace function private.complete_lab_visit(payload jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v public.visits; previous public.lab_results; result_id uuid := (payload->>'id')::uuid; bg public.blood_group_type; volume integer := (payload->>'prescribed_volume_ml')::integer; delta integer; field text;
begin
 if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>2048 then raise exception 'Invalid lab payload' using errcode='22023'; end if;
 if (select count(*) from jsonb_object_keys(payload))<>13 or exists(
   select 1 from jsonb_object_keys(payload) as f(key)
   where f.key not in ('id','visit_id','conducted_by','hemoglobin','wbc','platelets','rbc','hematocrit','mcv','mch','mchc','ferritin','prescribed_volume_ml')
 ) or exists(
   select 1 from jsonb_each(payload) as f
   where (f.key in ('id','visit_id','conducted_by') and jsonb_typeof(f.value)<>'string')
      or (f.key not in ('id','visit_id','conducted_by') and jsonb_typeof(f.value)<>'number')
 ) then
   raise exception 'Invalid lab payload' using errcode='22023';
 end if;
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
