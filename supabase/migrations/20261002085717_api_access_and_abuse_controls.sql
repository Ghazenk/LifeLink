-- Keep pending or rejected family-link requests from revealing the requester's
-- profile. Clinical reads already require an approved link through is_guardian.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated using (
  id = (select auth.uid())
  or (select private.active_role()) in ('admin', 'reception', 'lab')
  or ((select private.active_role()) in ('donor', 'caregiver') and private.is_guardian(id))
  or ((select private.active_role()) = 'patient' and exists (
    select 1 from public.guardianships g
    where g.donor_id = profiles.id
      and g.patient_id = (select auth.uid())
      and g.status = 'approved'
  ))
);

-- Shared, database-backed limits for the authenticated Edge endpoints.
-- Direct calls to the public wrapper can only spend the caller's own quota.
create table private.api_rate_counters (
  actor_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  window_start timestamptz not null,
  requests integer not null,
  units integer not null,
  primary key (actor_id, kind)
);
alter table private.api_rate_counters enable row level security;
revoke all on private.api_rate_counters from public, anon, authenticated;

create function private.consume_api_quota(kind text, cost integer default 1)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  actor_role text := private.active_role();
  period interval;
  max_requests integer;
  max_units integer;
  moment timestamptz := clock_timestamp();
  used_requests integer;
  used_units integer;
begin
  if actor is null or actor_role is null or cost is null or cost < 1 then
    raise exception 'Active account required' using errcode = '42501';
  end if;
  if kind = 'staff_create' and actor_role = 'admin' and cost = 1 then
    period := interval '1 day'; max_requests := 5; max_units := 5;
  elsif kind = 'staff_import' and actor_role in ('admin', 'reception') and cost between 1 and 100 then
    period := interval '1 day'; max_requests := 5; max_units := 100;
  elsif kind = 'meal_status' and actor_role in ('patient', 'donor') and cost = 1 then
    period := interval '5 minutes'; max_requests := 30; max_units := 30;
  else
    raise exception 'Action not allowed' using errcode = '42501';
  end if;
  insert into private.api_rate_counters as counter(actor_id, kind, window_start, requests, units)
  values(actor, kind, moment, 1, cost)
  on conflict on constraint api_rate_counters_pkey do update set
    window_start = case when counter.window_start <= moment - period then moment else counter.window_start end,
    requests = case when counter.window_start <= moment - period then 1 else counter.requests + 1 end,
    units = case when counter.window_start <= moment - period then cost else counter.units + cost end
  returning counter.requests, counter.units into used_requests, used_units;
  return used_requests <= max_requests and used_units <= max_units;
end;
$$;
revoke all on function private.consume_api_quota(text, integer) from public, anon;
grant execute on function private.consume_api_quota(text, integer) to authenticated;

create function public.consume_api_quota(kind text, cost integer default 1)
returns boolean language sql security invoker set search_path = '' as $$
  select private.consume_api_quota(kind, cost);
$$;
revoke all on function public.consume_api_quota(text, integer) from public, anon;
grant execute on function public.consume_api_quota(text, integer) to authenticated;
