# Input and credential audit — 2026-10-02

## Credentials

- Worktree and both existing Git revisions were checked for private-key blocks, Supabase secret/service-role keys, Groq/OpenAI keys, Google API keys, credential-bearing Postgres URLs, and tracked secret-file names. No private credential was found. The historical Supabase `anon` JWT and current `sb_publishable_` key are **public client identifiers**, not server credentials. Authorization depends on Supabase Auth, RLS and server checks.
- `SUPABASE_SERVICE_ROLE_KEY` is read only in `supabase/functions/manage-users/index.ts`; `AI_API_KEY` only in `supabase/functions/meal-plan/index.ts`. Both come from `Deno.env`. `supabase/functions/.env.example` has blank values. `.env` files are Git-ignored. Do not copy those values into Dart defines, Flutter assets, web HTML, build arguments, or logs.
- Supabase access tokens necessarily reach signed-in clients. They use the secure-session storage adapter; do not treat the public publishable key as an auth token.
- Any password/API key previously sent through chat or stored outside server secrets must be rotated by the operator. Git scans cannot prove a key was never copied, logged by a third party, or included in an old build artifact.

## Entry points and enforcement

| Input | Server-side protection | Client-side protection |
| --- | --- | --- |
| Email/password signup and staff-created accounts | Auth INSERT trigger requires age/terms, exact metadata keys, validated email, name, phone, role, blood group, donor screening; rejected insert stores no Auth/profile row. Password storage is Supabase Auth. | Signup fields validate format/length before request. |
| Sign-in, recovery and verification codes | Supabase Auth verifies credentials/tokens and rate limits; client never compares a stored password. | Password policy, code length and email form checks. |
| Admin/staff import API | JWT and active-role check, quota, 32 KB JSON cap, exact JSON MIME, strict body/account keys, email/name/phone/enum checks; service key is server-only. | Workbook type, compressed/decompressed size, ZIP parts, worksheet/row/column/formula checks. |
| Patient/donor/caregiver profile edits and admin settings | RLS/role checks plus profile trigger; app settings reject markup/control characters. | Flutter `Text` renders content as text, not HTML. |
| Reception search and share-code query/deep link | PostgREST parameterization/RLS; share RPC checks format, purpose, expiry and rate limit. | Search limited to 80 characters and safe alphabet; link/code length and regex limits. |
| QR camera and local file picker | Only normalized share code reaches database. Image bytes never leave device. | PNG/JPEG magic bytes, 8 MB file and 16 MP decode caps. |
| Visit/stock/lab RPCs | Typed SQL arguments, role/ownership checks, numeric ranges and exact JSON keys/types for visit/lab payloads. | Form numeric checks and local sync types. |
| AI generation | Active-user check, quota, fixed preference enums, exact JSON input keys and strict output schema; provider secret stays server-side. | Consent and clinician warning before request. |

PostgREST filters and RPC arguments use structured values rather than client-built SQL. No user input is passed to a shell command. The reception `.or()` search is the one textual PostgREST filter; it now has an explicit character allowlist and length limit. No user-uploaded file is persisted to Supabase Storage in this codebase.

The XLSX parser is a third-party dependency. The ZIP preflight limits normal archive metadata, but malicious archives with deliberately false size fields could still target parser bugs. Keep reception import restricted to trusted staff, update the parser dependency, and consider disabling bulk import for production with real patient data until it has a resource-isolated parsing service.
