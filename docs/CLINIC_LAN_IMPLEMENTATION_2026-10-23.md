# Clinic LAN implementation and remaining release gates

## What the code now does

Build a **separate Windows clinic client** with `--dart-define=LIFELINK_CLINIC_BUILD=true`. On first launch, a staff member enters the local server's HTTPS base URL and its **publishable** key. The client checks `/auth/v1/health` with normal certificate validation before saving those values in OS secure storage. It never accepts `http://`, localhost, URL credentials, or a path. The cloud/mobile build still uses its existing hosted backend.

Clinic sessions, session metadata, and Isar database files are namespaced by a digest of the server URL. Reception issues tokens through the local Supabase `queue_visit` RPC and displays success only after the transaction commits. Lab reads the shared `visits` queue from the local server (30-second screen refresh or manual Sync) and commits results through `complete_lab_visit`. Admin's existing queries and staff-management Edge Function target the selected local server. The local server, not any workstation's Isar cache, is the clinic authority. When it is unavailable, new clinic token and result operations fail visibly; they do not queue unsynchronized clinical changes on a workstation.

This is a **client foundation**, not an installed server or a cloud bridge. Neither two-PC operation nor internet-off operation has been verified yet. The prior Windows/cloud app still works on its existing backend and must not be mistaken for the clinic build.

## Target architecture

```text
Admin / Reception / Lab Windows clients
         | private LAN, HTTPS, authenticated user JWT
         v
Dedicated clinic server: reverse proxy + Supabase Auth/API/Postgres + Edge Functions
         | durable server-side outbound queue; internet may be absent
         v
Hosted Supabase: only explicitly approved mobile-facing projections
         ^
Patient / Donor / Caregiver phones over internet
```

Use the same database migrations and Edge Functions on the clinic server, with distinct credentials and a distinct Auth user population. Never put database passwords, service-role keys, or a cloud bridge secret in a Flutter build. Do not expose Postgres, Studio, or internal services to the LAN or internet; clients reach only the authenticated HTTPS API. Restrict the reverse proxy/firewall to the clinic subnet. Give the server a DHCP reservation or static address and a trusted DNS name/certificate; an IP address can be used only if the certificate explicitly covers that IP. **Do not disable TLS validation to make an IP work.** The clinic server needs UPS power, encrypted disk, protected backups, monitoring, and a recovery drill. The Windows clients need separate staff accounts and a patching/endpoint-security policy.

## Before a real installation

1. Choose and prepare the dedicated server. Current Supabase self-hosting uses Docker Compose and a gateway; do not point clients at a raw Postgres port. Apply migrations and deploy every required Edge Function. Provision synthetic staff and patient records first.
2. Configure a stable server address, HTTPS certificate, firewall, local DNS, and backup/restore. Test from both Windows laptops with internet disconnected but LAN/router still powered.
3. Build the clinic client separately, enter the same server URL and publishable key on each workstation, and sign in with separate Admin, Reception, and Lab test accounts. Confirm Reception creates a token and Lab sees it within 30 seconds, completes it, and Admin sees the result. Repeat after server reboot and after a WAN outage. Test concurrent edits, power failure, duplicate clicks, restore, and authorization across roles.
4. Design the cloud bridge before any patient data moves. Current `profiles.id` is an Auth account ID, so local and hosted projects cannot safely reuse it. Add a distinct clinical patient identifier and explicit mapping to hosted mobile accounts. Add a server-owned, idempotent outbound event queue with operation IDs, retry/backoff, conflict review, audit trail, and lag monitoring. Define which clinical fields may be published to phones and how consent/revocation works. Never mirror Auth tables or blindly replicate the whole clinic database.
5. Resolve the existing real-patient blockers before production: child/guardian identity and consent, blood-unit and compatibility ledger (the present inventory is only group volume), clinical result validation and sign-off, record retention and correction, incident response, privacy/legal review for Pakistan/Balochistan, and operational accountability. This FYP must not be used for actual transfusion decisions until the clinical workflow is independently validated.

## Build command

From the repository root on a configured Flutter/Windows development machine:

```powershell
flutter build windows --release --dart-define=LIFELINK_CLINIC_BUILD=true
```

The non-clinic build remains the existing hosted Supabase app. The clinic setup screen asks for a publishable key only; a service-role key must never be entered. After changing clinics, reinstall/clear the clinic configuration under administrator supervision so users cannot silently switch facilities. The current build has no cloud bridge and must show that fact in Settings.

The 23 October build check produced two distinct Windows release folders: `build/clinic-windows-release/` for the clinic setup build and `build/windows/x64/runner/Release/` for the ordinary cloud build. Copy the **entire folder**, including `data/` and DLLs, when installing on another PC; `lifelink.exe` alone does not contain the Flutter application. The clinic build still needs the dedicated HTTPS server before staff can sign in.

Verification on 23 October: 49 Flutter tests passed; targeted analyzer found no issues; both Windows builds completed. A web build failed in generated Isar code because its 64-bit schema IDs cannot be represented exactly in JavaScript. The web target is not currently supported; resolving it requires a web-capable persistence design rather than editing generated schema IDs. The two-PC WAN-off workflow and cloud bridge remain unverified.
