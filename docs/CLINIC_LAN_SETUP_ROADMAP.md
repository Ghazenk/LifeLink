# LifeLink clinic LAN: simple setup roadmap

**Status, 2 October 2026:** this is a build-and-install roadmap, not an installed clinic system. The existing default app still connects to the hosted Supabase project. Its 46 Flutter tests pass and its Windows debug build succeeds. Do not put real patient data into a LAN pilot until the release gates in [PUBLIC_RELEASE_GATE.md](PUBLIC_RELEASE_GATE.md) are met.

## The idea in one sentence

Reception, lab and admin each use their own computer, but all three talk to **one clinic server** on the same local network. The server keeps the clinic database. Internet is needed only to update the cloud/mobile side. CBC values remain manually entered and verified until the analyzer interface is known.

```text
Internet ── router ── Ethernet switch ── clinic server (always on)
                     ├── reception PC
                     ├── lab PC
                     └── admin PC
```

Unplugging the **internet/WAN** cable should leave the four clinic machines connected. Unplugging the switch, router power or server will stop the clinic system. Put server, switch and router on a UPS.

## Stage 1 — Prepare the network (you and a local IT technician)

For the current two-laptop direct-cable test and a beginner guide to adding a router, switch or future CBC analyzer, follow [ROUTER_AND_CBC_NETWORK_GUIDE.md](ROUTER_AND_CBC_NETWORK_GUIDE.md).

1. Use one dedicated server computer, a gigabit Ethernet switch with enough spare ports, Ethernet cables, the existing router, and a UPS. Do not use the reception PC as the server: someone closing it or putting it to sleep would stop everyone. For a full self-hosted Supabase stack, the [official guide](https://supabase.com/docs/guides/self-hosting/docker) lists 8 GB+ RAM, 4 cores+ and 80 GB+ SSD as its recommended baseline; choose storage and backup capacity for the clinic's actual data and retention needs.
2. Connect the router's **LAN** port to the switch. Connect the server and each staff PC to the switch. Keep the router's **WAN/Internet** port connected to the ISP. Put guest/patient Wi-Fi on a separate network; don't give guests access to the staff server.
3. In the router, reserve one IP address for the server, for example `192.168.10.10`. This is only an example: use the subnet your router actually gives out. Let staff PCs receive their IPs automatically. Record the server IP, router IP and who has administrator access.
4. On each Windows staff PC, run `ipconfig` and check that the address is on the same clinic subnet. Once the server is running, test `Test-NetConnection 192.168.10.10 -Port 443` in PowerShell, replacing the example address. Repeat after disconnecting **only the ISP/WAN cable**. A successful network test proves the connection, not that LifeLink is installed.

## Stage 2 — Install and secure the clinic server (developer/IT work)

1. Use a maintained server OS and the official [self-hosted Supabase Docker deployment](https://supabase.com/docs/guides/self-hosting/docker) for an initial **synthetic-data pilot**. Do not use `supabase start` as a production server; Supabase calls that local development stack not production-hardened. Self-hosting makes the clinic responsible for updates, monitoring, backups and recovery.
2. Generate new clinic-only keys/passwords and keep them on the server. Put an HTTPS reverse proxy in front of the API; install a trusted certificate on managed staff PCs. Supabase's [HTTPS guide](https://supabase.com/docs/guides/self-hosting/self-hosted-proxy-https) describes the proxy requirement. Never click through certificate warnings for patient data.
3. Firewall the server: staff PCs may reach the HTTPS API, but PostgreSQL, Studio, backup and administration ports must not be public. Do **not** set up router port-forwarding to the database. Separate guest Wi-Fi from the staff network.
4. Adapt/apply this repository's migrations, RLS policies and server functions to the clinic project. Create separate staff logins and test accounts. The hosted cloud accounts will **not** automatically appear in the clinic project. Confirm local login works with the ISP cable unplugged.
5. Set up encrypted backups outside the server, monitor backup success and practise restoring onto a spare machine. A UPS prevents brief outages; it is not a backup.

## Stage 3 — Change and test LifeLink (development work, not yet complete)

1. Make a **separate clinic staff build** that talks to the clinic API for patient lookup, visit/token issuance, lab queue, results, inventory and admin actions. The repository now supports paired build-time `LIFELINK_BACKEND_URL` and `LIFELINK_BACKEND_PUBLISHABLE_KEY` settings, but changing these settings alone does not complete the staff workflow. Use only the clinic **publishable** key in the app, never a server secret.
2. Give the clinic build its own application identity and secure-session namespace, so installing it cannot overwrite a cloud/mobile build or reuse a cloud login token. Keep the existing default cloud build unchanged.
3. Make the clinic server the single writer for clinical data. A reception token is saved once on the server; lab and admin refresh/subscribe to the shared queue. Do not share an Isar/SQLite file through a Windows folder and do not rely on each PC's local cache as the clinic database.
4. Give lab results, stock operations and cloud sends stable operation IDs so retry after a disconnection cannot duplicate a visit or blood issue. Replace blood-group-only volume totals with a reviewed blood-unit ledger before real clinical use.
5. On **two real PCs with synthetic patients**, issue a token at reception and see it on the lab PC. Disconnect WAN, repeat, record a lab result, reboot one PC, reconnect WAN, and verify exactly one result appears. Test two staff accounts and the admin view. Do not claim offline operation from a one-PC test.

## Stage 4 — Patient and donor phones (additional development work)

The clinic server sends approved changes **outbound** to hosted Supabase when internet returns. Phones continue to use the cloud. During an outage they may see an older result; show its last-sync time clearly. Mobile requests should enter a clinic review queue rather than overwrite clinical records. This replication, conflict handling and cloud identity mapping do **not** exist yet. Do not connect both clinic and cloud as equal writers to the same stock or result.

## Stage 5 — Clinical release checks

Finish the child-patient/guardian model, encrypted storage and backups, blood-unit inventory, staff permissions, device management, clinical review, policy/contact details, incident response, and end-to-end recovery tests in [PUBLIC_RELEASE_GATE.md](PUBLIC_RELEASE_GATE.md). The current FYP backend and local cache are not approved for real patient records. If the server itself is down, use a documented paper downtime procedure; LAN wires cannot fix a failed server.

## What works now versus later

| Item | Today | After the roadmap |
| --- | --- | --- |
| Existing cloud app | Default build still targets hosted Supabase; tests/build pass | Remains the mobile-facing app |
| Staff PCs wired together | Network cabling can be installed now | Staff API reaches shared clinic server |
| Reception token on lab PC without internet | **No** | Yes, after clinic server and staff-app migration |
| CBC machine import | **No**; verified manual entry | Optional model-specific validated adapter |
| Phone sees clinic updates | Hosted cloud data only | Outbound clinic-to-cloud sync with lag indicator |
| Real patient deployment | **No** | Only after release-gate evidence and operator approval |
