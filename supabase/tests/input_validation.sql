begin;
do $$
declare uid uuid; invalid jsonb; valid jsonb := '{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Patient","phone":"03001234567","role":"patient"}';
begin
  for invalid in select value from jsonb_array_elements(jsonb_build_array(
    valid || '{"full_name":"<script>alert(1)</script>"}'::jsonb,
    valid || '{"full_name":"x"}'::jsonb,
    valid || '{"phone":"0300abc4567"}'::jsonb,
    valid || '{"unknown":"data"}'::jsonb,
    valid || '{"medical_history":{"secret":true}}'::jsonb,
    valid || '{"role":"admin"}'::jsonb
  )) loop
    uid := gen_random_uuid();
    begin
      insert into auth.users(id,email,raw_user_meta_data) values(uid,uid||'@test.invalid',invalid);
      raise exception 'FAIL: invalid registration accepted';
    exception when check_violation then null; end;
    if exists(select 1 from auth.users where id=uid) then raise exception 'FAIL: rejected signup stored'; end if;
  end loop;
  uid := gen_random_uuid();
  insert into auth.users(id,email,raw_user_meta_data) values(uid,uid||'@test.invalid',valid);
  begin
    update public.profiles set full_name='<img src=x>' where id=uid;
    raise exception 'FAIL: markup profile name accepted';
  exception when invalid_parameter_value then null; end;
  begin
    update public.profiles set phone='123' where id=uid;
    raise exception 'FAIL: invalid profile phone accepted';
  exception when invalid_parameter_value then null; end;
end $$;
select 'PASS: strict registration and profile validation' as verification;
rollback;
