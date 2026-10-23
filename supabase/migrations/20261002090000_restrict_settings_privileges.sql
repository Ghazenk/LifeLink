-- TRUNCATE bypasses RLS. The earlier public settings table inherited broad
-- default grants, so restrict it to the intended read and admin update paths.
revoke all on table public.app_settings from public, anon, authenticated;
grant select on table public.app_settings to anon, authenticated;
grant update (
  operator_name, privacy_email, country, retention_notice, updated_at,
  copyright_agent_name, copyright_email, copyright_address, copyright_phone
) on table public.app_settings to authenticated;
-- settings_admin_update still restricts updates to the active admin role.
