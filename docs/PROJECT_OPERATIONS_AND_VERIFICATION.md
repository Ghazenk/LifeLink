# LifeLink: project operations and verified state

**Checked 23 October 2026.** This document describes the code and connected LifeLink Supabase project at this revision. It is an engineering handover, not a claim that the app is ready for real clinical use. Use synthetic records until the release gates below are closed.

## What is deployed and what is planned

The ordinary Windows/mobile build uses hosted Supabase project `osqirvdgczhvnacwxfgg` (`ap-south-1`, Mumbai). Supabase Auth signs users in; the `profiles` row determines whether the user sees Admin, Reception, Lab, Patient, Donor, or Caregiver. The publishable key in the client is public by design; the database service key and AI provider keys belong only in server-side secrets.

Flutter screens call role repositories. Riverpod providers create repositories and refresh their views. Authenticated Supabase requests reach PostgREST, RPCs, and Edge Functions; Postgres grants, row-level security (RLS), and server-side role checks are the access boundary. Isar is a per-device cache/outbox, **not** a shared database. A future clinic build can be pointed at a separately installed HTTPS LAN Supabase server, but the server and cloud bridge are not installed by this repository.

```text
Current:   Staff Windows app ── HTTPS ── hosted Supabase Auth/API/Postgres
           Patient/Donor phones ────────┘
           Each device: isolated Isar cache and pending clinical outbox

Future:    Staff PCs ── private LAN/HTTPS ── clinic server/Postgres
                                             └── reviewed outbound bridge ── hosted Supabase
           Patient/Donor phones ──────────────────────────────────────────────┘
```

There is no private VPC endpoint in the current desktop/mobile configuration. Clients use Supabase's public HTTPS API hostname. A publishable API key is **not** a firewall or a database credential. Direct database connections should remain restricted to administrators; workstation clients must use authenticated APIs, never a Postgres password. The separate clinic client requires a trusted HTTPS URL and publishable key and rejects `http://` and service keys. See [clinic implementation](CLINIC_LAN_IMPLEMENTATION_2026-10-23.md) for the remaining server, certificate, firewall, backup, and bridge work.

## Reception workflow and persistence

1. An Admin creates Reception/Lab staff through the `manage-users` Edge Function. The staff member verifies their email and sets a password through recovery. Ordinary sign-up does not offer a staff role.
2. Reception's **Approvals** screen reads pending patient/donor/caregiver profiles and can activate a profile. **Donation** and **Transfusion** search active donors/patients respectively. These searches call hosted Supabase directly in the current build.
3. On token issuance in the ordinary cloud build, `ReceptionRepository.issueToken` checks for a signed-in user and valid visit type, assigns a UUID and visible token, then commits a pending `LocalVisit` to Isar. The UI must label this **pending** until synchronization succeeds. `SyncManager` retries on connectivity/auth changes, app resume, and a periodic timer. `SyncEngine` sends `queue_visit` with the same UUID, making retries idempotent, then pulls only RLS-authorized visits/results/guardianships. A failed send retains the local pending record. A fresh write during a sync schedules another pass.
4. Lab refreshes its queue on screen entry, every 30 seconds while visible, or from its manual refresh button. Only a visit committed to the server can appear on another device. Lab completion uses `complete_lab_visit`; the server validates the payload and updates the result, visit, and inventory in one transaction.
5. **Inventory** reads hosted data. Manual stock adjustments call the protected `add_stock` RPC. Bulk XLSX import is limited to one worksheet, 100 records, 5 MB, plain values and an explicit age field, then calls `manage-users`; imported people must verify email and set a password.

In the **future clinic build**, token issuance calls the selected LAN server before showing success. Lab and Admin query that same server. If it is unavailable, the action fails visibly; no workstation-only clinical token is created. This protects against different workstations presenting conflicting authoritative records, but it means the clinic server must remain powered and reachable. There is currently **no** LAN-to-hosted-Supabase bridge. The default cloud build does **not** share data across PCs while the internet is down. Its local pending visit may sync when internet returns, provided the original device and account can resume; patient search, approvals, and inventory still require the backend.

## Security and data boundaries

- Password hashing, email verification, recovery tokens, and session issuance are handled by Supabase Auth. The app does not store plaintext passwords. Windows session data uses OS secure storage; clinical cache files in Isar are **not encrypted**.
- Patient/visit/lab ownership and staff roles are enforced by SQL grants, RLS, and validated RPCs, not by hiding UI controls. `supabase/tests/security_and_sync.sql` runs synthetic records inside `BEGIN`/`ROLLBACK` and checks isolation, privilege escalation, duplicate visit/lab requests, inventory authorization, and transaction atomicity.
- Reception search restricts characters before constructing a PostgREST `.or()` expression. Workbook and Edge Function inputs are bounded and validated. These controls complement, rather than replace, server-side access checks.
- `private` rate/share/provisioning tables have RLS with no client policies intentionally. The live Supabase security advisor separately warns that **leaked-password protection is disabled**; enable it in Supabase Auth settings and confirm the setting afterward.
- Do not place service-role, SMTP, database, or Groq credentials in Flutter defines, Git, screenshots, logs, or this document. If any previously shared secret is still active, rotate it in the provider dashboard.

## Build, configuration, and verification

Use the committed `pubspec.lock` and a compatible Flutter SDK. On Windows, install the Visual Studio C++ build workload and ATL. From the repository root:

```powershell
flutter pub get
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings lib test
flutter build windows --release --no-pub
```

`flutter analyze lib test` currently reports 48 experimental-member warnings from generated Isar `.g.dart` files, with no reported issues in handwritten code. Do not edit generated files to suppress them. The web build is not supported by the current native/Isar design. Windows release installation requires the **entire** output folder, including `data/` and DLLs, not just `lifelink.exe`.

For the clinic-client **foundation only**, build with `flutter build windows --release --dart-define=LIFELINK_CLINIC_BUILD=true`, then configure a separately deployed HTTPS clinic server and its publishable key on each workstation. Do not enter the hosted project's service key or point the client to raw Postgres. This command does not create the server or cloud bridge.

Verification on 23 October 2026:

| Check | Result and limit |
| --- | --- |
| Flutter tests | 49 passed locally. They include account flow, input validation, Isar cache, sync, and layout checks. |
| Analyzer | Handwritten code had no reported issues; 48 generated Isar warnings remain. |
| Live Supabase health | Project reported `ACTIVE_HEALTHY`. |
| Live rollback-only database suite | Passed signup/role, isolation, guardianship, visit/lab idempotency, stock and atomicity checks. No fixture records remained. |
| Live input validation suite | Passed strict registration and profile validation; test transaction rolled back. |
| Live account/clinical data | One active Admin and one active Reception; no active Lab, no visit, no lab result at time of check. |
| GitHub | Commit `6ef0c77943539ce27e0872cf13d653e42a516479` exists on `codex/supabase-sync-verified`; `main` remains at `9488530073432988ff4abed8d5c66afbf5e3e566`. The GitHub integration returned no CI status checks for the commit, so remote Actions success is unverified. |
| Two-device Reception → Lab test | Not run: no active Lab or patient/donor test account was available. Source-level and database tests do not prove a live cross-device handoff. |

The connected project's initial migrations are older than the files present here. Some October 2 migrations have matching names but different version stamps in the remote history. This repository is **not** a complete empty-project bootstrap. Reconcile schema and migration history before applying these files to another Supabase project; do not blindly replay them against the live project.

## Safe acceptance test before exhibition

Use **synthetic** identities and inboxes you control. Keep passwords and email codes private. First recover/sign in to the existing Admin account; create a Lab staff account in Admin and complete its email recovery. Create a synthetic adult patient/donor account through ordinary sign-up and verify it. On Reception, approve that profile if pending, issue a test token, and wait for **Up to date**. On Lab, refresh and confirm the same token appears; enter synthetic lab values and confirm completion. On Admin, refresh System and check the record. Confirm the expected `visits` and `lab_results` counts in Supabase after each step. Repeat a duplicate click/retry and verify no second visit or inventory adjustment. Finally interrupt internet on the **cloud build** and confirm that a locally pending token does not appear on another laptop until the original device reconnects and syncs. Do not perform an internet-off shared-workstation demonstration until a clinic server and bridge are installed and separately tested.

## Release blockers and ownership

The [public release gate](PUBLIC_RELEASE_GATE.md) controls use of real patient records. Its blockers include safe child/guardian records, clinical validation and sign-off, a blood-unit/compatibility ledger, encrypted endpoint storage, backup/restore, incident response, facility and privacy review, and (if clinic LAN operation is required) a tested clinic server plus selective cloud bridge. The hosted project is in Mumbai; assess Pakistan cross-border health-data obligations before real data is entered. The [Balochistan path](BALOCHISTAN_RELEASE_PATH.md) covers local facility questions; [security setup](SECURITY_AND_SETUP.md) and [legal audit](LEGAL_AUDIT_PAKISTAN.md) cover technical and policy details. Passing the tests above does not close those gates.

## Documentation map

Start here for architecture and verified behavior. Use [authentication security](AUTH_SECURITY.md), [API security](API_SECURITY.md), [SQL/architecture review](ARCHITECTURE_AND_SQL_REVIEW.md), [input and secret audit](INPUT_AND_SECRET_AUDIT.md), [password recovery](PASSWORD_RECOVERY_SETUP.md), [two-laptop test](TWO_LAPTOP_APP_TEST.md), and the [clinic LAN roadmap](CLINIC_LAN_SETUP_ROADMAP.md) for deeper procedures. Update this page's verification table whenever a real device test or deployment changes the evidence.
