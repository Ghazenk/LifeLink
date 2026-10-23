-- Validate data before auth.users is inserted, so a rejected signup retains
-- neither an Auth row nor a profile. User metadata is untrusted input.
create or replace function private.require_registration_eligibility()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare
  metadata jsonb := new.raw_user_meta_data;
  name text;
  phone_number text;
  requested_role text;
  history jsonb;
  staff_source boolean := coalesce(new.raw_app_meta_data->>'lifelink_creation_source','') = 'staff';
begin
  if metadata->'age_13_or_older' is distinct from 'true'::jsonb then
    raise exception using errcode='23514', message='Account creation requires age eligibility confirmation.';
  end if;
  if not staff_source and metadata->>'terms_version' is distinct from '2026-09-28' then
    raise exception using errcode='23514', message='Terms acceptance is required.';
  end if;
  if jsonb_typeof(metadata) is distinct from 'object' or octet_length(metadata::text) > 2048 then
    raise exception using errcode='23514', message='Invalid registration fields.';
  end if;
  if exists(select 1 from jsonb_object_keys(metadata) as field(key)
               where field.key not in ('age_13_or_older','terms_version','full_name','phone','role','blood_group','medical_history')) then
    raise exception using errcode='23514', message='Invalid registration fields.';
  end if;
  if new.email is null or length(new.email) > 254
     or new.email !~* '^[^[:space:]@<>]{1,64}@[A-Z0-9-]+(\.[A-Z0-9-]+)+$' then
    raise exception using errcode='23514', message='A valid email is required.';
  end if;
  name := btrim(metadata->>'full_name');
  phone_number := metadata->>'phone';
  requested_role := metadata->>'role';
  if name is null or length(name) not between 2 and 150
     or name ~ '[[:cntrl:]<>]' then
    raise exception using errcode='23514', message='Invalid account name.';
  end if;
  if phone_number is null or phone_number !~ '^[0-9]{11}$' then
    raise exception using errcode='23514', message='An 11-digit phone number is required.';
  end if;
  if requested_role not in ('patient','donor','caregiver') and not (
       staff_source and new.raw_app_meta_data->>'lifelink_provisioned'='true'
       and requested_role in ('reception','lab')
       and requested_role = new.raw_app_meta_data->>'role') then
    raise exception using errcode='23514', message='Invalid account role.';
  end if;
  if metadata->'blood_group' is not null and jsonb_typeof(metadata->'blood_group') <> 'null'
     and metadata->>'blood_group' not in ('A+','A-','B+','B-','AB+','AB-','O+','O-') then
    raise exception using errcode='23514', message='Invalid blood group.';
  end if;
  history := metadata->'medical_history';
  if history is not null and jsonb_typeof(history) <> 'null' then
    if requested_role <> 'donor' or jsonb_typeof(history) <> 'object'
       or octet_length(history::text) > 512 then
      raise exception using errcode='23514', message='Invalid screening answers.';
    end if;
    if exists(select 1 from jsonb_each(history) as field
                 where field.key not in ('donated_recently','fever_infection','taking_antibiotics','infectious_disease')
                    or jsonb_typeof(field.value) <> 'boolean') then
      raise exception using errcode='23514', message='Invalid screening answers.';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.require_registration_eligibility() from public,anon,authenticated;

-- Protect direct profile updates as well as signup-trigger inserts. Legacy
-- rows with incomplete phone data remain editable in unrelated fields.
create function private.validate_profile_input()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op='INSERT' or new.full_name is distinct from old.full_name then
    if length(btrim(new.full_name)) not between 2 and 150
       or new.full_name ~ '[[:cntrl:]<>]' then
      raise exception 'Invalid profile name' using errcode='22023';
    end if;
  end if;
  if (tg_op='INSERT' and new.phone is not null)
     or (tg_op='UPDATE' and new.phone is distinct from old.phone) then
    if new.phone is null or new.phone !~ '^[0-9]{11}$' then
      raise exception 'Invalid profile phone' using errcode='22023';
    end if;
  end if;
  if tg_op='INSERT' or new.medical_history is distinct from old.medical_history then
    if new.medical_history is not null then
      if new.role <> 'donor' or jsonb_typeof(new.medical_history) <> 'object'
         or octet_length(new.medical_history::text) > 512 then
        raise exception 'Invalid screening answers' using errcode='22023';
      end if;
      if exists(select 1 from jsonb_each(new.medical_history) as field
                where field.key not in ('donated_recently','fever_infection','taking_antibiotics','infectious_disease')
                   or jsonb_typeof(field.value) <> 'boolean') then
        raise exception 'Invalid screening answers' using errcode='22023';
      end if;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.validate_profile_input() from public,anon,authenticated;
create trigger validate_profile_input before insert or update on public.profiles
for each row execute function private.validate_profile_input();

alter table public.app_settings add constraint app_settings_no_markup_or_controls
check (
  operator_name !~ '[[:cntrl:]<>]'
  and privacy_email !~ '[[:cntrl:]<>]'
  and country !~ '[[:cntrl:]<>]'
  and retention_notice !~ '[[:cntrl:]<>]'
  and copyright_agent_name !~ '[[:cntrl:]<>]'
  and copyright_email !~ '[[:cntrl:]<>]'
  and copyright_address !~ '[[:cntrl:]<>]'
  and copyright_phone !~ '[[:cntrl:]<>]'
);
