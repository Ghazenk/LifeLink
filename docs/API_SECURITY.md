# API access and deployment security (2 October 2026)

LifeLink uses Supabase Auth, the PostgREST Data API, and two JWT-protected Edge
Functions. The public publishable key identifies the client; it is not a
database password. Authorization lives in Postgres RLS, checked RPCs, and the
Edge Functions. Client-side ID filters alone are not trusted.

| Resource or endpoint | Server authorization |
| --- | --- |
| `profiles` | Own row; active admin/reception/lab staff by clinic role; approved donor/caregiver access to a linked patient. Patients cannot read a requester's full profile. |
| `visits`, `lab_results` | Active clinic staff by role, or the patient and an approved caregiver/donor through the visit's patient ID. Direct client writes are revoked. |
| `guardianships` | Participants and authorized staff can read. Creation requires a short-lived share code; patient approval/revocation is checked against the patient's user ID. |
| `list_guardianship_requests` | Active patient receives only their own request IDs, statuses, and requester names. |
| `inventory` | Active clinic staff can read; checked staff RPCs perform changes. |
| `app_settings` | Public read is needed for policy pages. Only active admins can update approved columns. `TRUNCATE`, insert, delete, and all anonymous writes are revoked. |
| `manage-users` | Valid JWT, live active profile and staff role. Admin-only staff creation; admin/reception import. A server-side quota runs before account creation. |
| `meal-plan` | Valid JWT and live active donor/patient role. AI requests have a server-side quota; status checks have a separate quota. |
| Supabase Storage | No buckets exist in this project. |
| `lifelink-integration-check` | An old JWT-protected diagnostic route remains deployed as a fixed HTTP 404 response. It has no data or side effects; remove it from the project when convenient. |

The SQL in `supabase/tests/api_access_and_abuse.sql`, `sharing_codes.sql`, and
`security_and_sync.sql` exercises cross-account reads, pending/approved/rejected
links, role escalation, privileged writes, and rate limits against the connected
project inside rolled-back transactions.

## Abuse controls

- Supabase Auth's configured sign-in/sign-up and verification limits are 30
  attempts per five minutes per source IP. These are gateway controls; the app
  cannot replace them with a client-only counter.
- `manage-users`: at most five staff creations per active admin per day, or
  five import requests and 100 imported rows per active admin/reception user
  per day. Limits are stored in `private.api_rate_counters` and incremented
  atomically. Exceeding them returns HTTP 429.
- `meal-plan`: five generated drafts per user per day, at least one minute
  between drafts, and 100 drafts per project per day. Status checks are limited
  to 30 per user per five minutes.
- Guardian code redemption already limits connection attempts to 10 per 15
  minutes per user; reception check-ins to 200 per 15 minutes. Codes expire
  after 15 minutes.
- Data API reads still need a gateway or WAF for a general request-rate limit.
  RLS prevents unauthorized rows, but an authorized staff account could
  repeatedly enumerate records available to that role. Protect staff accounts
  and review their access before real patient use.

## HTTPS and secrets

- The app's configured Supabase URL and AI provider endpoint use HTTPS.
  Android disallows cleartext traffic; iOS App Transport Security defaults
  remain in place. The live Supabase HTTPS endpoint returned HSTS
  `max-age=31536000; includeSubDomains; preload` on 2 October 2026.
- Publish a web build only from an HTTPS host with HTTP-to-HTTPS redirect and
  HSTS. This repository has no production web host configuration, so that
  redirect cannot be verified here.
- `SUPABASE_SERVICE_ROLE_KEY`, SMTP credentials, and `AI_API_KEY` are only in
  Supabase-managed server settings. Edge logs omit request bodies, email
  addresses, passwords, tokens and IP addresses. Do not place these secrets in
  Flutter assets, web files, or Git.
- Existing `public.app_settings` privileges were reduced to explicit SELECT
  and admin-only column updates. Default privileges for future objects made
  by the `postgres` migration role were also changed to deny API roles until
  a migration grants access deliberately. Supabase's internal
  `supabase_admin` role has separate platform-managed defaults; every future
  public-schema migration still needs a grant and RLS review.
- Restrict **direct Postgres and pooler** access in Supabase Database Settings
  to the operator's known fixed IPv4/IPv6 CIDRs. No trusted administration or
  backup CIDRs were provided, so changing the allowlist now could lock out
  legitimate operators. [Supabase network restrictions](https://supabase.com/docs/guides/platform/network-restrictions)
  do **not** cover HTTPS Data/Auth/Storage APIs; those remain protected by
  Auth, RLS, quotas, and a production gateway/WAF.
- Enforce SSL for direct Postgres connections in Supabase Database Settings
  before connecting external administration tools. The app itself uses HTTPS
  APIs rather than a direct database password.

## Detection and operator review

Supabase already records Auth audit events, including sign-ins, sign-ups and
recovery requests, plus API gateway statuses. The project had both log sources
on 2 October 2026. Edge Functions now log structured `api_error` events with
endpoint, status and category, including access denials, throttling and server
errors. They log no request payload or identity. Clinic write RPCs also record
actions in the private audit table.

Use Supabase Logs Explorer for these aggregate checks; investigate spikes in
HTTP 400/401 on `/auth/v1/token`, 403 on `/rest/v1/` and `/functions/v1/`,
429 responses, and repeated 5xx function errors. Filter to an appropriate
time window and review the source request metadata in the restricted dashboard:

```sql
select log_attributes['request.path'] as path,
       log_attributes['response.status_code'] as status,
       count() as events
from logs
where source = 'edge_logs'
  and log_attributes['response.status_code'] in ('400','401','403','429','500','502','503')
group by path, status
order by events desc
limit 30;
```

No external alert destination or log drain is configured. Supabase log
retention depends on the project plan. A public deployment needs an operator
to review these logs regularly and add alerts through an approved destination.
For stronger bot control on web, [configure Supabase Auth CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha)
with the operator's Turnstile/hCaptcha site and secret keys; no provider keys
or production web domain are available in this workspace.
