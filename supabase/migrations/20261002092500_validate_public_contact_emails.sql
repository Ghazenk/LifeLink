-- Admin-controlled public contact values are still untrusted text.
alter table public.app_settings add constraint app_settings_contact_email_format
check (
  (privacy_email = '' or privacy_email ~* '^[^[:space:]@<>]{1,64}@[A-Z0-9-]+(\.[A-Z0-9-]+)+$')
  and (copyright_email = '' or copyright_email ~* '^[^[:space:]@<>]{1,64}@[A-Z0-9-]+(\.[A-Z0-9-]+)+$')
);
