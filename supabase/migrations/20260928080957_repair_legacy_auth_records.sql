-- Repair legacy accounts that were inserted directly into Auth before the Admin API workflow.
-- Preserve password hashes, email confirmation state, public roles and account IDs.
update auth.users u set
  confirmation_token=coalesce(u.confirmation_token,''),
  recovery_token=coalesce(u.recovery_token,''),
  email_change_token_new=coalesce(u.email_change_token_new,''),
  email_change=coalesce(u.email_change,''),
  phone_change=coalesce(u.phone_change,''),
  phone_change_token=coalesce(u.phone_change_token,''),
  email_change_token_current=coalesce(u.email_change_token_current,''),
  reauthentication_token=coalesce(u.reauthentication_token,'')
where exists (select 1 from public.profiles p where p.id=u.id)
  and (u.confirmation_token is null or u.recovery_token is null or u.email_change_token_new is null
    or u.email_change is null or u.phone_change is null or u.phone_change_token is null
    or u.email_change_token_current is null or u.reauthentication_token is null);

-- Only repair password accounts with no identities at all. Do not link OAuth identities.
with legacy as (
  select u.id,u.email,u.email_confirmed_at,u.created_at from auth.users u
  where u.email is not null and u.email<>'' and u.encrypted_password is not null and u.encrypted_password<>''
    and exists(select 1 from public.profiles p where p.id=u.id)
    and not exists(select 1 from auth.identities i where i.user_id=u.id)
), repaired as (
  insert into auth.identities(provider_id,user_id,identity_data,provider,created_at,updated_at)
  select id::text,id,jsonb_build_object('sub',id::text,'email',email,'email_verified',email_confirmed_at is not null,'phone_verified',false),
    'email',coalesce(created_at,now()),now() from legacy
  on conflict(provider_id,provider) do nothing returning user_id
)
update auth.users u set raw_app_meta_data=coalesce(u.raw_app_meta_data,'{}'::jsonb)||jsonb_build_object('provider','email','providers',jsonb_build_array('email'))
from repaired r where u.id=r.user_id;
