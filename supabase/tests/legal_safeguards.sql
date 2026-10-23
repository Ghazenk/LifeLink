begin;
do $$
declare test_id uuid; metadata jsonb; before_users bigint; before_profiles bigint;
begin
  select count(*) into before_users from auth.users;
  select count(*) into before_profiles from public.profiles;
  for metadata in select value from jsonb_array_elements('[{}, {"age_13_or_older":false}, {"age_13_or_older":"true"}, {"age_13_or_older":null}, {"age_13_or_older":1}, {"age_13_or_older":true}]'::jsonb) loop
    test_id:=gen_random_uuid();
    begin
      insert into auth.users(id,email,raw_user_meta_data) values(test_id,test_id||'@test.invalid',metadata);
      raise exception 'FAIL: invalid registration accepted';
    exception when check_violation then null; end;
    if exists(select 1 from auth.users where id=test_id)
      or exists(select 1 from public.profiles where id=test_id)
      or exists(select 1 from auth.identities where user_id=test_id)
      then raise exception 'FAIL: rejected registration retained'; end if;
  end loop;
  if (select count(*) from auth.users)<>before_users or (select count(*) from public.profiles)<>before_profiles then
    raise exception 'FAIL: rejected attempts changed row counts';
  end if;
  -- Staff/admin provisioning also requires age, even with trusted creation source.
  begin
    insert into auth.users(id,raw_app_meta_data,raw_user_meta_data)
      values(gen_random_uuid(),'{"lifelink_creation_source":"staff"}','{"age_13_or_older":false}');
    raise exception 'FAIL: staff bypassed age gate';
  exception when check_violation then null; end;
  test_id:=gen_random_uuid();
  begin
    insert into auth.users(id,email,raw_user_meta_data) values(test_id,test_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test User","phone":"03001234567","role":"admin"}');
    raise exception 'FAIL: unauthorized role accepted';
  exception when check_violation then null; end;
  insert into auth.users(id,email,raw_user_meta_data) values(test_id,test_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test User","phone":"03001234567","role":"patient"}');
  if not exists(select 1 from public.profiles where id=test_id and role='patient' and status='pending') then
    raise exception 'FAIL: eligible registration failed'; end if;
  -- Email-metadata cannot forge the trusted staff creation source.
  begin
    insert into auth.users(id,raw_user_meta_data) values(gen_random_uuid(),'{"age_13_or_older":true,"lifelink_creation_source":"staff"}');
    raise exception 'FAIL: forged creation source accepted';
  exception when check_violation then null; end;
  test_id:=gen_random_uuid();
  insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data) values(gen_random_uuid(),gen_random_uuid()||'@test.invalid','{"lifelink_creation_source":"staff","lifelink_provisioned":true,"role":"lab"}','{"age_13_or_older":true,"full_name":"Test Staff","phone":"03001234567","role":"lab"}');
end $$;
select 'PASS: invalid ages/missing terms rejected without rows; eligible public and staff accounts accepted' as result;
rollback;
