-- User confirmed Pakistan. Preserve any explicitly configured country.
alter table public.app_settings alter column country set default 'Pakistan';
update public.app_settings set country='Pakistan',updated_at=now() where trim(country)='';
