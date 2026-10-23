-- Auth Admin createUser does not expose its app_metadata to our BEFORE INSERT
-- eligibility trigger. A short-lived, one-use server token bridges that gap
-- without trusting public signup metadata to assign staff roles.
create table private.staff_provisioning (
  email text primary key,
  staff_role public.user_role not null check (staff_role in ('reception', 'lab')),
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null
);
alter table private.staff_provisioning enable row level security;
revoke all on private.staff_provisioning from public, anon, authenticated;
grant select, insert, update, delete on private.staff_provisioning to service_role;

create function public.prepare_staff_provisioning(
  p_email text, p_role text, p_token_hash text
) returns void language plpgsql security invoker set search_path = '' as $$
begin
  if p_email is null or length(p_email) > 254
     or p_email !~* '^[^[:space:]@<>]{1,64}@[A-Z0-9-]+(\.[A-Z0-9-]+)+$'
     or p_role not in ('reception', 'lab')
     or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid staff provisioning request' using errcode = '22023';
  end if;
  insert into private.staff_provisioning(email, staff_role, token_hash, expires_at)
  values (lower(p_email), p_role::public.user_role, p_token_hash,
          clock_timestamp() + interval '10 minutes')
  on conflict (email) do update set
    staff_role = excluded.staff_role,
    token_hash = excluded.token_hash,
    expires_at = excluded.expires_at;
end;
$$;
revoke all on function public.prepare_staff_provisioning(text,text,text)
  from public, anon, authenticated;
grant execute on function public.prepare_staff_provisioning(text,text,text)
  to service_role;

create function private.provision_staff_before_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  invite_token text := new.raw_user_meta_data->>'staff_invite_token';
  allowed_role public.user_role;
begin
  if invite_token is null then return new; end if;
  if invite_token !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid staff invitation' using errcode = '23514';
  end if;
  select staff_role into allowed_role
  from private.staff_provisioning
  where email = lower(new.email)
    and token_hash = encode(extensions.digest(invite_token, 'sha256'), 'hex')
    and expires_at > clock_timestamp()
  for update;
  if allowed_role is null or new.raw_user_meta_data->>'role' is distinct from allowed_role::text then
    raise exception 'Invalid or expired staff invitation' using errcode = '23514';
  end if;
  delete from private.staff_provisioning where email = lower(new.email);
  new.raw_user_meta_data := new.raw_user_meta_data - 'staff_invite_token';
  new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object('lifelink_creation_source', 'staff',
                          'lifelink_provisioned', true, 'role', allowed_role::text);
  return new;
end;
$$;
revoke all on function private.provision_staff_before_insert()
  from public, anon, authenticated;
create trigger a_provision_staff_before_insert
before insert on auth.users for each row
execute function private.provision_staff_before_insert();
