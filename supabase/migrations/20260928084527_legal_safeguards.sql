-- All Auth insert paths, including direct REST, Admin API, future OAuth and OTP.
-- A BEFORE trigger rejects without retaining an auth user/profile/identity.
-- No birth date, rejected input, or attempted email is stored by this function.
create or replace function private.require_registration_eligibility()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if (new.raw_user_meta_data->'age_13_or_older') is distinct from 'true'::jsonb then
    raise exception using errcode='23514', message='Account creation requires age eligibility confirmation.';
  end if;
  -- Admin-created/imported users have not themselves accepted terms; never fabricate consent.
  -- Public registrations must explicitly acknowledge this version.
  if coalesce(new.raw_app_meta_data->>'lifelink_creation_source','') <> 'staff'
     and (new.raw_user_meta_data->>'terms_version') is distinct from '2026-09-28' then
    raise exception using errcode='23514', message='Terms acceptance is required.';
  end if;
  return new;
end;
$$;
revoke all on function private.require_registration_eligibility() from public,anon,authenticated;
create trigger require_registration_eligibility before insert on auth.users
for each row execute function private.require_registration_eligibility();

alter table public.app_settings
  add column copyright_agent_name text not null default '' check(length(copyright_agent_name)<=150),
  add column copyright_email text not null default '' check(length(copyright_email)<=254),
  add column copyright_address text not null default '' check(length(copyright_address)<=500),
  add column copyright_phone text not null default '' check(length(copyright_phone)<=80);
grant update(copyright_agent_name,copyright_email,copyright_address,copyright_phone)
on public.app_settings to authenticated;
-- Existing settings_admin_update RLS applies to these new columns.
