begin;
do $$ begin
  if has_table_privilege('anon','public.app_settings','TRUNCATE')
     or has_table_privilege('authenticated','public.app_settings','TRUNCATE')
     or not has_table_privilege('anon','public.app_settings','SELECT')
     or has_table_privilege('anon','public.profiles','SELECT') then
    raise exception 'FAIL: public table privileges';
  end if;
end $$;
do $$
declare p uuid := gen_random_uuid(); c uuid := gen_random_uuid(); r uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (p,p||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Patient","phone":"03001234567","role":"patient"}'),
    (c,c||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Caregiver","phone":"03001234567","role":"caregiver"}'),
    (r,r||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Reception","phone":"03001234567","role":"patient"}');
  update public.profiles set status='active' where id in(p,c,r);
  update public.profiles set role='reception' where id=r;
  insert into public.guardianships(donor_id,patient_id,status) values(c,p,'pending');
  perform set_config('lifelink.api_test',jsonb_build_object('p',p,'c',c,'r',r)::text,true);
end $$;
set local role authenticated;
do $$
declare ids jsonb := current_setting('lifelink.api_test')::jsonb; n integer; i integer;
begin
  perform set_config('request.jwt.claim.sub',ids->>'p',true);
  select count(*) into n from public.profiles where id=(ids->>'c')::uuid;
  if n<>0 then raise exception 'FAIL: pending caregiver profile exposed to patient'; end if;
  select count(*) into n from public.list_guardianship_requests() where donor_name is not null and status='pending';
  if n<>1 then raise exception 'FAIL: patient cannot identify pending requester'; end if;
  perform set_config('request.jwt.claim.sub',ids->>'c',true);
  select count(*) into n from public.list_guardianship_requests();
  if n<>0 then raise exception 'FAIL: caregiver can list patient requests'; end if;
  perform set_config('request.jwt.claim.sub',ids->>'p',true);
  for i in 1..30 loop
    if not public.consume_api_quota('meal_status') then raise exception 'FAIL: early status throttle'; end if;
  end loop;
  if public.consume_api_quota('meal_status') then raise exception 'FAIL: status throttle bypass'; end if;
  begin
    perform public.consume_api_quota('staff_import',1);
    raise exception 'FAIL: patient can consume staff quota';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claim.sub',ids->>'r',true);
  if not public.consume_api_quota('staff_import',100) then raise exception 'FAIL: import limit too low'; end if;
  if public.consume_api_quota('staff_import',1) then raise exception 'FAIL: import unit limit bypass'; end if;
end $$;
reset role;
update public.guardianships set status='approved'
where donor_id=(current_setting('lifelink.api_test')::jsonb->>'c')::uuid;
set local role authenticated;
do $$
declare ids jsonb := current_setting('lifelink.api_test')::jsonb;
begin
  perform set_config('request.jwt.claim.sub',ids->>'p',true);
  if exists(select 1 from public.profiles where id=(ids->>'c')::uuid) then
    raise exception 'FAIL: approved link exposes full requester profile';
  end if;
  if not exists(select 1 from public.list_guardianship_requests() where status='approved') then
    raise exception 'FAIL: approved request unavailable';
  end if;
end $$;
reset role;
update public.guardianships set status='rejected'
where donor_id=(current_setting('lifelink.api_test')::jsonb->>'c')::uuid;
set local role authenticated;
do $$
declare ids jsonb := current_setting('lifelink.api_test')::jsonb;
begin
  perform set_config('request.jwt.claim.sub',ids->>'p',true);
  if exists(select 1 from public.profiles where id=(ids->>'c')::uuid) then
    raise exception 'FAIL: rejected link still exposes profile';
  end if;
  if exists(select 1 from public.list_guardianship_requests()) then
    raise exception 'FAIL: rejected request still listed';
  end if;
end $$;
rollback;
select 'PASS: requester identity minimized, profile isolation, approved request, API quotas and role checks' as verification;
