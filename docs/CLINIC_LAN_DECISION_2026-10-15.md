# Clinic LAN implementation decision (15 October 2026)

**Status update (23 October 2026): a separate clinic client foundation is implemented, but the local server and cloud bridge are not deployed or approved for real patient data.** See `CLINIC_LAN_IMPLEMENTATION_2026-10-23.md` for the current code path. This document records the target architecture; an IP setting alone is not a working offline clinic system.

## Desired behaviour

Admin, Reception and Lab use separate staff accounts and computers, but write to one authoritative clinic database on a computer that remains powered on. The computers reach it over the private LAN through a router/switch, with or without an internet connection. Patient and donor phones use hosted Supabase. The clinic server publishes approved changes to the hosted project after internet returns, with an explicit last-sync time and retry/error queue. A staff workstation is a client, not a second server or a separate writer.

```text
Reception PC ─┐
Lab PC ───────┼── private switch/router ── clinic server (HTTPS API + DB + outbox)
Admin PC ─────┘                              │
                                            └── outbound sync when WAN is up ── hosted Supabase ── phones
```

The server's LAN address should be reserved in the router (or set statically in a direct-cable pilot). Its address is a **destination for the staff app**, not a replacement for staff identity. Each employee signs in separately. The dedicated machine has not yet been chosen; this development laptop must not be assumed to be that server. Router power and the server must remain available during a WAN outage; a UPS and an encrypted, tested backup are required for real use.

The staff Windows build needs a **first-run connection screen** where an operator enters the clinic server address and its public client key, tests the HTTPS connection, and sees the server identity before sign-in. The address must be saved per installation and changeable through Settings after signing out. It should accept a stable DNS name or IP *only with a trusted HTTPS certificate*; do not silently fall back to hosted Supabase if the server is unreachable. Keep cloud/mobile and clinic session storage, recovery client and local caches in separate namespaces so changing the backend cannot expose one backend's data or token on the other. A bare IP such as `10.77.0.1` will fail certificate validation unless its certificate includes that IP; using a local DNS name with a trusted certificate is usually simpler.

## Evidence in the current app

| Workflow | Current path | WAN-off consequence |
| --- | --- | --- |
| Reception token | `ReceptionRepository.issueToken` writes to the receptionist's Isar and `SyncEngine` later calls cloud `queue_visit` | The lab PC cannot read the receptionist's Isar. |
| Lab queue/result | `LabRepository.getLiveQueue` filters its own Isar by the logged-in lab user; result is locally queued and later calls cloud `complete_lab_visit` | No cross-PC queue; lab cannot complete a token it has not received. |
| Patient search/approval and stock | `ReceptionRepository` reads/writes hosted Supabase directly | Unavailable without WAN. |
| Admin staff, dashboard and visit actions | `AdminRepository` uses hosted Supabase and `manage-users` | Unavailable without WAN. |
| Staff sign-in | `AuthRepository.signIn` requires Supabase Auth and a fresh profile read | New sign-in fails without WAN. A cached profile is not an offline server authorization mechanism. |
| Current build override | `AppConstants` accepts one paired backend URL and publishable key | Pointing a build at a LAN server does not create cloud replication, identity mapping or safe migration. |

The present Isar data is a per-device, unencrypted cache/outbox. Do not share its files via Windows file sharing or copy them between PCs. Do not treat a successful Ethernet ping or the existing LAN test page as proof of a working clinic workflow.

## Chosen architecture and ownership

1. For a **synthetic-data pilot**, run a separate, pinned self-hosted Supabase deployment on the clinic server. Apply the repository schema and server functions in a staging environment, then create separate local staff accounts. Build a staff-only Windows client against its HTTPS LAN endpoint and publishable key. The default phone build continues to use hosted Supabase. The clinic server is the only writer of clinic visits, results and stock.
2. Do **not** synchronize two Supabase databases bidirectionally. A server-side outbox publishes approved clinic events to the cloud with stable operation IDs, record versions, ordering, retry state and an operator-visible conflict queue. Cloud/mobile changes enter a separate review inbox before they affect clinic-owned records. Never put a service-role key or cloud-sync credential in a Flutter build.
3. Keep patient clinical identity distinct from mobile login identity. This is necessary for children without accounts and for offline clinic lookup. Map the clinical subject to verified mobile/guardian accounts on the server. Do not create false email accounts for children.
4. Staff login and authorization must work locally during WAN loss. The clinic server, not an old device cache, checks role, status and session expiry on every request. A deactivated employee is blocked at the LAN server. Once the clinic is used for real data, manage device enrollment, disk encryption, audit, backups and offline revocation procedures.
5. Clinical stock needs a reviewed unit/bag ledger and reservation flow before real use. The current blood-group `volume_ml` total is not sufficient to prevent double issue or establish traceability. The CBC interface remains manual until the machine model and LIS specification are known.

## Implementation sequence and acceptance gates

1. **Network and server pilot:** confirm server machine, RAM/storage, Windows/WSL/Docker support, always-on power, and staff LAN reachability. Reserve its LAN IP, add trusted HTTPS, firewall the API to staff devices, and keep database/Studio private. Use only synthetic data.
2. **Staff clinic backend:** install a pinned server stack, apply/test migrations and RLS, provision local staff accounts, and give the Windows staff build a separate app identity/session namespace plus first-run connection screen. Test Admin, Reception and Lab sign-in with WAN disconnected.
3. **Single LAN write path:** move patient lookup, approvals, token issuance, lab queue/results, staff management, dashboard and inventory operations to the clinic server. Remove the per-device clinical outbox from staff workflows only after migration/recovery of any pending drafts. Show explicit server connection, pending publication and stale-data status.
4. **Two-PC WAN-off test:** issue one synthetic token on Reception; it appears in Lab and Admin while internet is unplugged. Complete the result once; restart both clients; confirm no duplicate token/result. Test simultaneous stock changes, invalid/revoked staff, server outage and recovery. A manual refresh button remains available alongside automatic updates.
5. **Cloud bridge:** publish only approved, versioned clinic events to hosted Supabase; verify exact mobile ownership and no duplicate result after retries/reboots. Reconnect WAN and observe lag/backlog until fully caught up. Test conflicts and a failed publication without losing local data.
6. **Real-data release:** meet every gate in `PUBLIC_RELEASE_GATE.md`, including encrypted storage/backups, child/guardian model, clinical review, legal/operator details and a tested restore drill. Synthetic pilot success alone is not clinical approval.

Current Supabase documentation: [self-hosting with Docker](https://supabase.com/docs/guides/self-hosting/docker), [self-hosted HTTPS proxy](https://supabase.com/docs/guides/self-hosting/self-hosted-proxy-https). The 2026 changelog notes a self-hosted gateway change from Kong to Envoy; deployment instructions must be pinned and rechecked rather than copied from an older guide.
