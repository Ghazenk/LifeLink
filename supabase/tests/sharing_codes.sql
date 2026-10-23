begin;
do $$
declare p uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); r uuid:=gen_random_uuid(); v uuid:=gen_random_uuid();
begin
 insert into auth.users(id,email,raw_user_meta_data) values
 (p,p||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Patient","phone":"03001234567","role":"patient"}'),
 (c,c||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Caregiver","phone":"03001234567","role":"caregiver"}'),
 (other,other||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Other Caregiver","phone":"03001234567","role":"caregiver"}'),
 (r,r||'@test.invalid','{"age_13_or_older":true,"terms_version":"2026-09-28","full_name":"Test Reception","phone":"03001234567","role":"patient"}');
 if (select role from public.profiles where id=c)<>'caregiver' then raise exception 'FAIL caregiver signup'; end if;
 update public.profiles set status='active' where id in (p,c,other,r);
 update public.profiles set role='reception' where id=r;
 insert into public.visits(id,user_id,token_number,type) values(v,p,'TEST-'||v,'transfusion');
 insert into public.lab_results(visit_id,hemoglobin,wbc,platelets) values(v,10,5,250);
 perform set_config('lifelink.test_ids',jsonb_build_object('p',p,'c',c,'other',other,'r',r,'v',v)::text,true);
end $$;
set local role authenticated;
do $$
declare ids jsonb:=current_setting('lifelink.test_ids')::jsonb; share jsonb; checkin jsonb; answer jsonb; request uuid; i integer;
begin
 if has_function_privilege('authenticated','public.request_guardianship(uuid,uuid)','execute') then raise exception 'FAIL UUID bypass'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'p',true);
 share:=public.create_share_code('guardian'); checkin:=public.create_share_code('checkin');
 if share->>'code' !~ '^LL-G-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$' then raise exception 'FAIL format'; end if;
 perform set_config('lifelink.test_share',share->>'code',true);
 perform set_config('request.jwt.claim.sub',ids->>'c',true);
 begin perform public.create_share_code('guardian'); raise exception 'FAIL caregiver may invite as patient'; exception when insufficient_privilege then null; end;
 begin perform public.redeem_share_code(checkin->>'code','checkin'); raise exception 'FAIL caregiver checkin lookup'; exception when insufficient_privilege then null; end;
 answer:=public.redeem_share_code(share->>'code','guardian'); request:=(answer->>'request_id')::uuid;
 if answer->>'status'<>'pending' or request is null then raise exception 'FAIL request'; end if;
 if exists(select 1 from public.profiles where id=(ids->>'p')::uuid) or exists(select 1 from public.visits where id=(ids->>'v')::uuid) or exists(select 1 from public.lab_results where visit_id=(ids->>'v')::uuid) then raise exception 'FAIL pending sees records'; end if;
 if (public.redeem_share_code(share->>'code','guardian')->>'request_id')::uuid<>request then raise exception 'FAIL retry'; end if;
 begin perform public.respond_guardianship(request,'approved'); raise exception 'FAIL caregiver self approves'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',ids->>'other',true);
 if (public.redeem_share_code(share->>'code','guardian')->>'ok')::boolean then raise exception 'FAIL reused by another account'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'p',true);
 perform public.respond_guardianship(request,'approved');
 perform set_config('request.jwt.claim.sub',ids->>'c',true);
 if not exists(select 1 from public.profiles where id=(ids->>'p')::uuid) or not exists(select 1 from public.visits where id=(ids->>'v')::uuid) or not exists(select 1 from public.lab_results where visit_id=(ids->>'v')::uuid) then raise exception 'FAIL approved denied'; end if;
 begin perform public.add_stock(gen_random_uuid(),'O+',100); raise exception 'FAIL caregiver stock'; exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub',ids->>'p',true);
 perform public.respond_guardianship(request,'rejected');
 perform set_config('request.jwt.claim.sub',ids->>'c',true);
 if exists(select 1 from public.profiles where id=(ids->>'p')::uuid) or exists(select 1 from public.visits where id=(ids->>'v')::uuid) or exists(select 1 from public.lab_results where visit_id=(ids->>'v')::uuid) then raise exception 'FAIL revoked still sees'; end if;
 if public.redeem_share_code(share->>'code','guardian')->>'status'<>'rejected' then raise exception 'FAIL retry reopens revoked'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'r',true);
 answer:=public.redeem_share_code(checkin->>'code','checkin');
 if answer->'profile'->>'id'<>ids->>'p' then raise exception 'FAIL reception checkin'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'p',true);
 perform public.revoke_share_code('checkin');
 perform set_config('request.jwt.claim.sub',ids->>'r',true);
 if (public.redeem_share_code(checkin->>'code','checkin')->>'ok')::boolean then raise exception 'FAIL revoked checkin'; end if;
 perform set_config('request.jwt.claim.sub',ids->>'other',true);
 for i in 1..10 loop answer:=public.redeem_share_code('bad','guardian'); end loop;
 if answer->>'message' not like 'Too many attempts%' then raise exception 'FAIL rate limit'; end if;
end $$;
reset role;
do $$ begin
 if not exists(select 1 from private.share_attempts where attempts>10) then raise exception 'FAIL attempts not persisted'; end if;
 if exists(select 1 from private.share_codes where octet_length(code_hash)<>32) then raise exception 'FAIL unhashed code'; end if;
 update private.share_codes set expires_at=now()-interval '1 second' where owner_id=(current_setting('lifelink.test_ids')::jsonb->>'p')::uuid;
end $$;
set local role authenticated;
do $$ begin
 perform set_config('request.jwt.claim.sub',current_setting('lifelink.test_ids')::jsonb->>'c',true);
 if (public.redeem_share_code(current_setting('lifelink.test_share'),'guardian')->>'ok')::boolean then raise exception 'FAIL expired accepted'; end if;
end $$;
rollback;
select 'PASS: caregiver role, purpose restrictions, single use, retry, consent, revocation, hashing, expiry, rate limits, check-in' verification;
