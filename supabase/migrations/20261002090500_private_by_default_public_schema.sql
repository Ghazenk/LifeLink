-- Supabase's older public-schema defaults grant newly created objects to API
-- roles immediately. Make future postgres-owned objects opt-in, per Supabase's
-- documented API security guidance. Existing explicit grants are unaffected.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;
