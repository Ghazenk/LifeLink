-- A patient needs to identify a connection requester, not read the entire
-- donor/caregiver profile (including contact and medical metadata).
drop policy profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (
  id = (select auth.uid())
  or (select private.active_role()) in ('admin', 'reception', 'lab')
  or ((select private.active_role()) in ('donor', 'caregiver') and private.is_guardian(id))
);

create function private.list_guardianship_requests()
returns table(id uuid, status text, donor_name text)
language sql stable security definer set search_path = '' as $$
  select g.id, g.status::text, p.full_name
  from public.guardianships g
  join public.profiles p on p.id = g.donor_id
  where auth.uid() is not null
    and private.active_role() = 'patient'
    and g.patient_id = auth.uid()
    and g.status in ('pending', 'approved')
  order by g.created_at desc;
$$;
revoke all on function private.list_guardianship_requests() from public, anon;
grant execute on function private.list_guardianship_requests() to authenticated;

create function public.list_guardianship_requests()
returns table(id uuid, status text, donor_name text)
language sql stable security invoker set search_path = '' as $$
  select * from private.list_guardianship_requests();
$$;
revoke all on function public.list_guardianship_requests() from public, anon;
grant execute on function public.list_guardianship_requests() to authenticated;
