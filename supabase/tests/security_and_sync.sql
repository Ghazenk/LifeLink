begin;
do $$ begin
 if has_function_privilege('anon','public.complete_lab_visit(jsonb)','execute')
 or has_function_privilege('authenticated','public.admin_import_user(text,text,text,text,text)','execute')
 or has_table_privilege('anon','public.profiles','select') then raise exception 'FAIL: anonymous or legacy access'; end if;
end $$;
do $$
declare admin_id uuid:=gen_random_uuid(); lab_id uuid:=gen_random_uuid(); donor_id uuid:=gen_random_uuid(); patient_id uuid:=gen_random_uuid(); attacker_id uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email,raw_user_meta_data) values
 (admin_id,admin_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Admin","phone":"03001234567","role":"patient"}'),
 (lab_id,lab_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Lab","phone":"03001234567","role":"patient"}'),
 (donor_id,donor_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Donor","phone":"03001234567","role":"donor"}'),
 (patient_id,patient_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Patient","phone":"03001234567","role":"patient"}'),
 (attacker_id,attacker_id||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Attacker","phone":"03001234567","role":"patient"}');
 if exists(select 1 from public.profiles where id=attacker_id and (role<>'patient' or status<>'pending')) then raise exception 'FAIL: signup privilege escalation'; end if;
 update public.profiles set role='admin',status='active' where id=admin_id;
 update public.profiles set role='lab',status='active' where id=lab_id;
 update public.profiles set status='active',blood_group='O+' where id in (donor_id,patient_id);
 perform set_config('lifelink.test_ids',jsonb_build_object('admin',admin_id,'lab',lab_id,'donor',donor_id,'patient',patient_id,'attacker',attacker_id)::text,true);
end $$;
set local role authenticated;
do $$
declare ids jsonb:=current_setting('lifelink.test_ids')::jsonb; visit_id uuid:=gen_random_uuid(); result_id uuid:=gen_random_uuid(); request_id uuid:=gen_random_uuid(); payload jsonb; share jsonb; initial_volume integer; n integer;
begin
 perform set_config('request.jwt.claim.sub',ids->>'donor',true);
 select count(*) into n from public.profiles where id=(ids->>'patient')::uuid;
 if n<>0 then raise exception 'FAIL: donor can read unrelated patient'; end if;
 begin
   update public.profiles set role='admin' where id=(ids->>'donor')::uuid;
   raise exception 'FAIL: self promotion permitted';
 exception when insufficient_privilege then null; end;
 begin
   perform public.add_stock(gen_random_uuid(),'O+',100);
   raise exception 'FAIL: donor can mutate stock';
 exception when insufficient_privilege then null; end;
 begin
   insert into public.lab_results(id,visit_id) values(result_id,visit_id);
   raise exception 'FAIL: direct clinical inserts permitted';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',ids->>'patient',true);
 share := public.create_share_code('guardian');
 perform set_config('request.jwt.claim.sub',ids->>'donor',true);
 request_id := (public.redeem_share_code(share->>'code','guardian')->>'request_id')::uuid;
 begin
   perform public.respond_guardianship(request_id,'approved');
   raise exception 'FAIL: donor can self-approve guardianship';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',ids->>'patient',true);
 perform public.respond_guardianship(request_id,'approved');
 perform set_config('request.jwt.claim.sub',ids->>'donor',true);
 select count(*) into n from public.profiles where id=(ids->>'patient')::uuid;
 if n<>1 then raise exception 'FAIL: approved guardian cannot view linked profile'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'admin',true);
 begin
   perform public.queue_visit(jsonb_build_object('id',gen_random_uuid(),'user_id',ids->>'donor','type','donation','token_number','TEST','created_at',now(),'extra','ignored'));
   raise exception 'FAIL: visit extra field accepted';
 exception when invalid_parameter_value then null; end;
 perform public.queue_visit(jsonb_build_object('id',visit_id,'user_id',ids->>'donor','type','donation','token_number','TEST-'||visit_id,'created_at',now()));
 perform public.queue_visit(jsonb_build_object('id',visit_id,'user_id',ids->>'donor','type','donation','token_number','TEST-'||visit_id,'created_at',now()));
 select coalesce(volume_ml,0) into initial_volume from public.inventory where blood_group='O+';
 initial_volume:=coalesce(initial_volume,0);
 perform set_config('request.jwt.claim.sub',ids->>'lab',true);
 payload:=jsonb_build_object('id',result_id,'visit_id',visit_id,'conducted_by',ids->>'lab','hemoglobin',12,'wbc',7,'platelets',250,'rbc',4,'hematocrit',40,'mcv',90,'mch',30,'mchc',33,'ferritin',50,'prescribed_volume_ml',450);
 begin
   perform public.complete_lab_visit(payload || '{"extra":"ignored"}'::jsonb);
   raise exception 'FAIL: lab extra field accepted';
 exception when invalid_parameter_value then null; end;
 perform public.complete_lab_visit(payload);
 perform public.complete_lab_visit(payload);
 if (select volume_ml from public.inventory where blood_group='O+')<>initial_volume+450 then raise exception 'FAIL: retry adjusted inventory twice'; end if;
 if not exists(select 1 from public.visits where id=visit_id and status='completed') then raise exception 'FAIL: visit not completed'; end if;
 begin
   perform public.complete_lab_visit(payload||'{"hemoglobin":13}'::jsonb);
   raise exception 'FAIL: conflicting lab retry accepted';
 exception when unique_violation then null; end;
 perform set_config('request.jwt.claim.sub',ids->>'patient',true);
 if exists(select 1 from public.visits where id=visit_id) then raise exception 'FAIL: unrelated patient sees donor visit'; end if;
 if exists(select 1 from public.lab_results where id=result_id) then raise exception 'FAIL: unrelated patient sees lab result'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'admin',true);
 perform public.add_stock(gen_random_uuid(),'AB-',100);
 update public.app_settings set operator_name='Security test' where id=true;
 if not exists(select 1 from public.app_settings where operator_name='Security test') then raise exception 'FAIL: admin settings denied'; end if;
 visit_id:=gen_random_uuid(); result_id:=gen_random_uuid();
 perform public.queue_visit(jsonb_build_object('id',visit_id,'user_id',ids->>'patient','type','transfusion','token_number','TEST-'||visit_id,'created_at',now()));
 perform set_config('request.jwt.claim.sub',ids->>'lab',true);
 payload:=payload||jsonb_build_object('id',result_id,'visit_id',visit_id,'prescribed_volume_ml',2000);
 begin
   perform public.complete_lab_visit(payload);
   raise exception 'FAIL: insufficient stock accepted';
 exception when invalid_parameter_value then null; end;
 if exists(select 1 from public.lab_results where id=result_id) or exists(select 1 from public.visits where id=visit_id and status='completed') then raise exception 'FAIL: partial clinical write'; end if;
 update public.app_settings set operator_name='Unauthorized' where id=true;
 if exists(select 1 from public.app_settings where operator_name='Unauthorized') then raise exception 'FAIL: nonadmin settings write'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'patient',true);
 perform public.consume_ai_quota();
 begin
  perform public.consume_ai_quota();
  raise exception 'FAIL: AI burst limit bypass';
 exception when raise_exception then
  if sqlerrm like 'FAIL:%' then raise; end if;
 end;
end $$;
reset role;
select 'PASS: signup, role escalation, record isolation, guardianship approval, atomic lab retry, conflicting retry, stock authorization' as verification;
rollback;
