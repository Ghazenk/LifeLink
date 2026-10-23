# LifeLink implementation and security review

The 2 October 2026 endpoint, ownership, abuse and deployment review is in
[API_SECURITY.md](API_SECURITY.md). It supersedes older endpoint-version and
database-grant statements below.



Reviewed on 27 September and rechecked on 28 September 2026. This is an FYP implementation, not a clinical certification or a guarantee that every vulnerability has been eliminated.



## What changed



The existing logo, roles and principal workflows remain. The shared responsive theme and navigation follow the supplied design references and Apple design notes. Privacy and cookie/local-storage notices are reachable before sign-in and from Settings (gear icon) in every portal, including pending accounts. Admin > Settings edits the operator name, privacy email, country and retention notice. Defaults use LifeLink; no fictional contact details were published.



The live Supabase project `osqirvdgczhvnacwxfgg` now has restricted access policies, protected account roles, server-authorized staff provisioning and atomic clinical/inventory operations. An authenticated user can no longer read all clinical records or promote their own account. Signup metadata cannot grant staff access. The old fixed-password import and stock-adjustment RPCs are inaccessible to app roles. The existing accounts were checked for the old shared import password; none matched. Existing staff identity/authorization should still be confirmed by the operator because historic role assignment was unsafe.



## Data flow



Flutter repositories write account-owned Isar outbox records. A single-flight SyncEngine verifies the current account, pushes visits before lab results, then pulls paginated records permitted by Supabase RLS. Full lab values, visit completion, inventory changes and an audit event commit together inside one server transaction. A retry with identical result ID and measurements is idempotent; conflicting measurements and insufficient stock are rejected without partial changes. Failed writes remain pending. Cloud pulls preserve pending edits and remove synced records no longer returned by access policies.



Every local clinical row belongs to the signed-in account that created or fetched it. Rows from older app versions without an owner remain quarantined; they are neither displayed nor uploaded as another user's work. Do not delete an old installation containing unsynced records until an administrator has reconciled those records with its originating user.



Sign-out clears the current account's synced cache and all cached profiles. Pending work stays isolated to its original account for later sign-in and synchronization. Logout does not depend on network availability: even if server revocation fails, locally signed-out sessions clear synced records; the pending outbox is preserved. The cloud icon displays sync status and a manual retry. A pending record can require administrator review when the server rejects an invalid record, revoked access or a conflict; the app does not silently discard it.



Reception and lab devices need connectivity to exchange new tokens. Offline changes stay on their originating device. Thirty-second polling, auth changes and connectivity changes trigger synchronization. This is eventual synchronization, not a claim of real-time delivery. Local historical data is not evidence that a medical procedure is currently authorized.



Sessions use Flutter Secure Storage rather than plaintext preferences. The old preferences session is removed once; existing installations must sign in again. The app requests global revocation on sign-out and enforces a 12-hour absolute lifetime plus a 30-minute inactivity timeout, with timestamps kept in secure storage. Supabase access tokens expire after one hour and refresh-token replay detection is enabled. Server-side session timeboxing requires a paid Supabase plan and remains a production prerequisite. Isar's clinical cache is **not encrypted by this app**. Use synthetic records for the FYP; a deployment with real patient records needs an approved encrypted-storage/device-management design, data retention rules and operator review. Android backup and cleartext traffic are disabled; the Isar inspector is disabled. Native desktop dependencies include secure storage's platform requirements.



## Clinical boundaries



The old CBC auto-fill generated simulated values. It was removed from the clinical workflow. Enter independently verified measurements and the actual recorded volume; donation volume is no longer silently assumed to be 500 mL. Physical analyzer support requires its protocol, hardware and a validated integration. Donation intervals and transfusion estimates in the existing app remain planning indicators, not clinical clearance or prescriptions.



AI creates optional general adult meal inspiration, not a therapeutic diet. Users must confirm clinician suitability and consent for each request. Only two enumerated food preferences reach the AI vendor; no name, identifier, blood group, diagnosis or lab results are sent. Doctor review warnings appear before and after generation. Output structure/length/content is validated, but validation cannot prove medical safety. Limits are five requests per user per day, one per minute, and 100 per deployment per day. Failed provider requests may still consume quota. Drafts remain in screen memory, not clinical records.



## Server deployment and configuration



Pakistan legal audit: see [LEGAL_AUDIT_PAKISTAN.md](LEGAL_AUDIT_PAKISTAN.md) for item-by-item evidence, processor inventory, operator actions and legal limitations. New registration requires age eligibility; old app versions must be updated to register. Public signup also requires Terms acceptance. These rules do not change existing passwords or login. The 13+ threshold is a project rule, not Pakistan legal consent.

Additional applied migrations: `20260928084527_legal_safeguards.sql` and `20260928134944_pakistan_operator_defaults.sql`. Updated `manage-users` version 2 is active.

Applied migrations: `supabase/migrations/20260927145509_security_hardening.sql` and `supabase/migrations/20260928080957_repair_legacy_auth_records.sql`.



Existing accounts failed login because legacy Auth records contained NULL confirmation/token fields and lacked email identities. The repair normalizes these fields and restores missing email identities without changing passwords, account IDs, roles or confirmation state. Live HTTP verification returned 200 for password login and profile retrieval and 204 for logout using a disposable synthetic account, which was then deleted. Sign-in accepts email and password for all roles; donor/patient selection appears only during registration. Existing credentials should be retried in the rebuilt app. See [Supabase’s documented NULL-token error](https://supabase.com/docs/guides/troubleshooting/scan-error-on-column-confirmation_token-converting-null-to-string-is-unsupported-during-auth-login-a0c686).

Deployed functions: `manage-users`, `meal-plan`, both with JWT verification and live active-account/role checks.



This migration targets the existing LifeLink database, including its earlier schema and manual lab-column additions. It is not a complete blank-database bootstrap. Do not run it again against the connected project. Before moving to a new project, export the existing baseline schema and reconcile the older remote migration history; the repository did not contain that baseline when this review started.



AI deliberately remains unavailable without server secrets. In Supabase Dashboard > Edge Functions > Secrets, configure:



- `AI_PROVIDER`: `groq` (default) or `xai`.

- `AI_API_KEY`: your provider key. Never put it in Flutter, Git, chat, public policy settings or an APK.

- `AI_MODEL`: a model supported by that provider. For Groq, `openai/gpt-oss-120b` is the default; `openai/gpt-oss-20b` is a smaller alternative. Confirm availability and free-tier limits in your account. Both use strict structured output; this improves formatting, not clinical accuracy. For xAI, select a model your account supports; costs may apply.

- `ALLOWED_ORIGINS`: comma-separated exact browser origins if you later deploy a web client. Native requests without Origin are supported. Unknown browser origins are denied.



Supabase supplies its own URL/anon/service-role environment variables to Edge Functions. The service-role secret is used only server-side for staff/account provisioning. Browser support needs separate review because this app's current Isar/native integrations are its primary target.



Imported spreadsheets require six columns: name, 11-digit phone, donor/patient role, valid blood group, a real email and age_13_or_older set to TRUE after staff verification. Do not select a workbook containing children under 13. Maximum 100 accounts and 5 MB per file. Imports use random inaccessible passwords and unverified emails, not a shared password. They create pending accounts; the user must use the configured email-code recovery flow before first use. Signup and recovery codes are eight digits, single-use, and expire after 15 minutes. Review failed row numbers rather than rerunning an entire partially imported workbook. A network timeout may require checking whether an account was created before retrying.



## Verification and remaining release work



Verification result: **29 Flutter tests passed**, **5 Deno tests passed**, both Edge Functions passed Deno type checks, and both Windows and Android debug builds succeeded. Flutter analysis found no errors; 48 warnings are from generated Isar experimental-index methods.



Automated Flutter tests cover responsive roles, privacy pages, AI consent/disabled state, account isolation, offline timestamp preservation, failed writes, full lab payloads, cache revocation, concurrent sync/account switching and sign-out retention. Deno checks validate both server functions and exercise AI input/output, body limits, missing authentication and CORS. Transactional tests in `supabase/tests/security_and_sync.sql` run against the live database and roll back synthetic fixtures; they cover role escalation, guardian consent, record isolation, retry atomicity/conflicts, insufficient stock, policy settings authorization and AI limits. Unauthenticated live function requests returned HTTP 401.



The Supabase security advisor now reports only **leaked-password protection disabled**. Enable it in Auth settings if supported by the project plan. Also review the available Postgres maintenance update (the project was running 17.6.1.166), staff ownership, SMTP, backups, restore procedures and retention before a real deployment. No database upgrade or production-readiness certification was performed.



The unused serial-port plugin was removed. Kotlin incremental compilation is disabled in this project because its Windows dependency cache is on C: while the repository is on D:, which caused cross-drive cache failures. See [Kotlin compilation settings](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).



Windows secure storage needs the Visual Studio C++ ATL component. The missing component was installed during this work. iOS/macOS signing, entitlements and device behavior still need testing on Apple hardware; Android debug packaging succeeded on 28 September 2026 after the tooling dependencies downloaded. The file_picker library compile SDK is aligned to API 36 because its lifecycle dependency requires it. Verified with `gradlew.bat assembleDebug --offline --console=plain --max-workers=2`; APK: `build/app/outputs/apk/debug/app-debug.apk`. Android device validation and production signing/application ID remain operator release tasks; the current build is debug signed. Live Groq generation subsequently passed on 1 October 2026; see the verification update below.



## References



- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)

- [Edge Function authentication](https://supabase.com/docs/guides/functions/auth)

- [Leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)

- [Groq rate limits](https://console.groq.com/docs/rate-limits) and [data handling](https://console.groq.com/docs/your-data)

- [Microsoft build-tool components](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools)



## Caregiver accounts, Settings and QR sharing (29 September 2026)

Applied migrations: `20260929002051_caregiver_role.sql`, `20260929002053_sharing_codes.sql`.

- Signup offers Patient, Donor and Caregiver. Caregivers have their own portal and need Reception activation. They are not eligible clinic donation/transfusion targets simply because they support a patient. The spreadsheet importer still supports donor/patient accounts only; caregivers use signup.
- Settings is the common home for Privacy, Terms, Cookies & storage and Copyright. Signup retains policy links and Terms acceptance. The cloud icon shows sync status only. Admin retains editable operator details.
- A patient opens Guardians > Generate code. An active donor/caregiver scans it in Family/Connections or enters the short `LL-G-....-....-....` code. The request remains pending until approved. Patients can revoke existing access in Guardians. All sharing actions require an online server response.
- Patient Home and Donor Profile generate a separate `LL-C` clinic check-in code. Reception uses Scan / enter check-in code in Donation/Transfusion, verifies identity and explicitly issues a visit. Generating, scanning or looking up a QR does not create a visit or approve record access.
- Codes contain 48 random bits, expire after 15 minutes, are stored only as SHA-256 hashes, and are bound to one recipient. A replacement or revocation invalidates the prior code. Same-recipient retries are idempotent; a rejected connection is not reopened by replay. Generation is limited to once per 5 seconds; redemption to 10 connection attempts or 200 staff check-in attempts per 15 minutes per account.
- QR photos decode locally using camera + zxing2; no barcode cloud provider. Camera permission is opt-in on Android/iOS. Desktop users import a PNG/JPEG or enter the code. Camera captures are deleted after use. The app rejects images over 8 MB or 16 megapixels.
- Mobile QR payloads use `lifelink://connect?code=...`. Android/iOS app scheme handlers are configured; scanners vary in custom-scheme support, so the in-app scanner or typed code is the supported fallback. There is no invented public website/HTTPS domain. Windows has no registered protocol handler.
- Old UUID-only requests are disabled at the server. Obsolete local sharing drafts are discarded on sync and must be re-created using a code; clinical outboxes are preserved. Existing server-approved connections remain valid. No passwords were changed.
- Private sharing tables deliberately have RLS enabled without public policies, and no direct client grants. Only authorized definer RPCs operate on them. Supabase informational `rls_enabled_no_policy` findings on these two private tables are expected default-deny behavior, not missing access grants.

### Next stage: child patients (not implemented in this update)

A child's clinical identity must be separated from the adult's login identity. A one-year-old should have a patient record, not a fabricated email/password or a false age declaration. Plan a staff-created child record with date of birth, verified parent/legal-guardian authority, a recorded consent basis and audit history; link the adult caregiver account to that record. Child records must work through Reception visits, lab results, RLS and offline sync before removing the current under-13 restriction. Supporting-caregiver access is not proof of parental authority. AI diet drafts remain adult-only. Use synthetic records until the operator's clinical/legal release review is complete.


Current verification: 37 Flutter tests pass, including caregiver layouts at 360/1280 pixels, caregiver signup, Settings links, code validation/revocation, local QR image roundtrip, and existing auth/Isar/clinical flows. `security_and_sync.sql` and `sharing_codes.sql` passed against the live database using rolled-back synthetic fixtures. Sharing tests include before/after approval and revocation for profiles, visits and labs. Analyzer reports zero errors/info and the same 48 generated Isar warnings. Windows and Android debug builds succeeded. The current APK is `build/app/outputs/apk/debug/app-debug.apk`; run Windows from `build/windows/x64/runner/Debug/lifelink.exe` with its companion data/DLL files. Real Android/iOS camera permissions and external-scanner app launches still need device testing; Apple builds were not run on Windows. Android microphone and legacy broad-storage permissions inherited from the camera package are removed in the app manifest.


## Replacing the Groq key

Open https://supabase.com/dashboard/project/osqirvdgczhvnacwxfgg/functions/secrets and save:

- `AI_PROVIDER` = `groq`
- `AI_API_KEY` = your new Groq key (keep it out of source, APKs, logs and chat)
- `AI_MODEL` = `openai/gpt-oss-120b` (or the smaller `openai/gpt-oss-20b`)

Replace `AI_API_KEY` on this same page whenever rotating it; no APK rebuild or function redeployment is required for a secret change. Revoke the old key in Groq after replacing it; a key pasted into chat should be revoked now. A free-tier allowance is controlled by Groq, not guaranteed by LifeLink. Setting a secret is separate from deploying the function. The operator has now saved the provider secrets. Their values were not read or copied into source. A live generation test passed on 1 October 2026.

The hardened meal-plan function rejects truncated/refused responses, malformed/extra fields, known prohibited clinical claims, and obvious vegetarian mismatches. Tests cover these cases, but these checks cannot establish nutritional adequacy, allergy safety, or medical suitability. Results remain general adult meal inspiration requiring doctor/dietitian review, never a child diet or prescribed thalassemia diet. Verify generation with an active donor/patient account after setting the secrets. Only cuisine/preference are sent to Groq; clinical records are not included.

Groq hardening verification: `meal-plan` version 2 deployed ACTIVE with JWT verification enabled. Deno type checking and all 9 backend tests passed. Live unauthenticated calls return 401. This earlier deployment was superseded by version 6 and a successful live generation test on 1 October 2026. These server-only changes do not require a new APK.


## AI and recovery verification — 1 October 2026

- Deployed meal-plan version 6 with JWT verification enabled. Live authenticated Groq generation returned HTTP 200, three meals, and the required doctor-review warning. The validator still rejects clinical claims and malformed drafts; clinician questions are now fixed application copy. Successful generation does not guarantee medical accuracy or future provider availability.
- Recovery backend verified with a disposable synthetic account: OTP verified, replay rejected, password changed, old password rejected, new password accepted; test account deleted. No existing account password changed. The diagnostic function was replaced by an inert 404 handler and local test credentials removed.
- Added Forgot password, email-code verification, password confirmation, resend cooldown, sanitized errors and an isolated non-persisted recovery client. Recovery never enters the clinical portal. Global sign-out is requested after changing the password; any failure is reported.
- Gmail SMTP credentials were saved in the Supabase dashboard on 1 October 2026, and delivery to the operator's Gmail inbox was confirmed. The hosted Reset password template is now saved from `supabase/templates/recovery.html`; its dashboard preview contains the recovery token and no confirmation link or localhost URL. Supabase accepted a fresh recovery-email request after the change (HTTP 200). **Still required:** confirm receipt of that code and complete the real inbox/device password-change test in `docs/PASSWORD_RECOVERY_SETUP.md`.
- Adult-managed child clinical profiles remain a previously deferred feature. Do not bypass the age gate by entering a false age. FYP functionality does not certify legal compliance, clinical safety, or production readiness.

Verification for this update: 37 existing Flutter tests passed; both new password recovery widget tests passed after fixing the test's scrolling. All 9 Deno tests passed. Flutter analysis reports 48 pre-existing generated Isar warnings and no new recovery-code findings. Windows debug and Android debug builds succeeded. Diagnostic endpoint returned 404 and the database confirmed zero remaining integration test accounts. Email delivery, actual-device recovery and Apple builds remain unverified.
