# LifeLink authentication security baseline

Verified on 1 October 2026 against Supabase project `osqirvdgczhvnacwxfgg`.

## Passwords

- Supabase Auth stores the six current password accounts as bcrypt hashes. LifeLink never stores plaintext passwords or password hashes in public tables, Isar, logs, or analytics.
- New and changed passwords are enforced in both Supabase Auth and the app at 12–128 characters with uppercase, lowercase, numeric, and symbol characters.
- Leaked-password protection remains unavailable on the project's Free plan. Enable it before a real deployment by upgrading and turning on **Authentication → Sign In / Providers → Email → Prevent use of leaked passwords**.
- Staff provisioning no longer accepts or exposes a temporary password. The server creates a random inaccessible credential and sends a recovery code so the staff member verifies the inbox and chooses the password.

## Email verification and recovery

- **Confirm email** is enabled in Supabase Auth. Anonymous sign-in and manual identity linking are disabled.
- Signup and recovery emails contain eight-digit codes rather than browser links. Both code types expire after 900 seconds and are single-use.
- The app provides code entry, resend cooldowns, generic failures, and a non-persisted isolated recovery client.
- Secure email change and secure password change are enabled. The recovery flow globally revokes sessions after a password change.
- Supabase sends security notifications when a password or email address changes.

## Sessions

- Supabase access tokens expire after 3600 seconds. Refresh-token replay detection is enabled with the recommended 10-second reuse interval.
- Server-enforced time-boxed and inactivity sessions are unavailable on the Free plan. LifeLink therefore enforces a 12-hour absolute lifetime and 30-minute inactivity timeout locally, persists those timestamps in OS secure storage, checks them on resume, and requests global server revocation on expiry.
- Explicit sign-out requests global revocation and always removes the local secure credential and account cache.
- Upgrade Supabase and configure server-side session time-boxing and inactivity limits before treating this as a production clinical control. A client-side timeout cannot revoke a token copied from a compromised device when the revocation request cannot reach the server.

## Abuse controls and keys

- Supabase limits signup/sign-in to 30 requests per five minutes per source IP. Token verification is limited to 30 requests per five minutes; recovery and confirmation resends also have cooldowns.
- The app contains only the Supabase `sb_publishable_...` key. Publishable keys identify public clients and are not authorization secrets. RLS and authenticated Edge Functions enforce access.
- `SUPABASE_SERVICE_ROLE_KEY`, SMTP credentials, and AI provider keys stay in Supabase-managed server secrets. The repository scan found no service-role, SMTP, or AI secret values.
