# LifeLink clinic LAN: start with two Windows laptops

**Status: preparation guide, 24 October 2026.** This guide gets the physical network ready, explains the software installation order, and gives tests for the eventual clinic server. The **current ordinary LifeLink build uses hosted Supabase**. A separate clinic Windows client foundation exists, but the self-hosted clinic server, its complete schema/functions, and the clinic-to-cloud sync bridge are **not installed or verified**. A cable or IP setting alone will not make LifeLink share clinical records without internet. Use **synthetic records only** until the [public release gates](PUBLIC_RELEASE_GATE.md) are closed.

## The goal and the names

For the first test, **Laptop A = Admin + temporary clinic server**, and **Laptop B = Reception**. Later, a third PC = Lab. More Reception/Lab PCs can join the same staff LAN and server. The server must remain awake and powered while staff work. A dedicated server can replace Laptop A later.

```text
                          Internet (may fail)
                                 |
                        router WAN/Internet port
                                 |
                       router LAN ports / staff LAN
                          |                 |
             Laptop A: Admin + server   Laptop B: Reception
                          |                 |
                   one clinic API + PostgreSQL database

Later: Lab and more staff PCs connect to spare LAN ports or an added switch.
Patient/donor phones use hosted Supabase via the internet, not the clinic database directly.
```

**LAN** means the private connection among your PCs. **WAN/Internet** is the router's connection to the internet. **PostgreSQL** is the database inside the proposed self-hosted Supabase server. **Supabase Auth/API** sits in front of it and checks staff identity and permissions. The Flutter app must use the authenticated HTTPS API; it must not connect to PostgreSQL with a database password.

## Step 0 — Gather and check before changing settings

1. Have two Windows laptops, their power adapters, a powered router with **at least two LAN sockets**, and two working Ethernet cables. A socket marked **WAN**, **Internet**, or **DSL** is not a staff LAN socket. If the router has only one LAN socket, use a small Gigabit Ethernet switch, or use the existing direct-cable method for a network-only test.
2. On Laptop A, open **Settings > System > About** and note installed RAM, processor and Windows version. Open **File Explorer > This PC** and note free SSD space. A full self-hosted Supabase installation requires at least 4 GB RAM, two CPU cores and 40 GB SSD; 8 GB+ RAM, four cores+ and 80 GB+ SSD are the recommended starting point. These are server-stack requirements, not guarantees for a real clinic. [Supabase requirements](https://supabase.com/docs/guides/self-hosting/docker).
3. Record the router's make/model and the number of sockets marked LAN. Do **not** share the Wi-Fi password, router-admin password, database passwords, email codes or API secrets in chat or screenshots.
4. Keep the current working LifeLink cloud app installed. Do not uninstall it, delete its data, or put real patient data into this pilot. Make a separate Windows clinic build only after the server is ready.
5. **You do not need standalone PostgreSQL, pgAdmin, PocketBase, an MCP connector, or Flutter on the Reception laptop.** The proposed server stack includes PostgreSQL. The clinic app is copied as a complete Windows release folder when ready. The Word tutorial supplied earlier uses PocketBase `shared_tasks`; it is a different example and its open API rules are not suitable for clinical data.

## Step 1 — Connect the two laptops to the router

1. Plug the router into power. Connect Laptop A to **LAN 1** and Laptop B to **LAN 2** using Ethernet cables. Leave the router's WAN/internet cable connected for the first test. Do not use a guest Wi-Fi network for staff PCs.
2. The previous direct-cable test used manual `10.77.0.1` and `10.77.0.2` addresses. Change **both laptops' Ethernet adapters** back to automatic addressing before relying on router DHCP: press **Win+R**, type `ncpa.cpl`, press Enter; right-click **Ethernet > Properties > Internet Protocol Version 4 (TCP/IPv4) > Properties**; select **Obtain an IP address automatically** and **Obtain DNS server address automatically**; confirm. This affects Ethernet only; leave Wi-Fi alone.
3. On each PC, open **Command Prompt**, run `ipconfig`, and find the **Ethernet adapter** section. Record its IPv4 Address, Subnet Mask and Default Gateway in the worksheet below. Ignore Wi-Fi, virtual adapters and Bluetooth entries. If Ethernet says **Media disconnected**, inspect cable and LAN socket. If it has `169.254.x.x`, the router did not supply DHCP; check router power/DHCP or use the direct-cable fallback below.
4. The two Ethernet addresses should be distinct and in the router's LAN range, such as `192.168.1.20` and `192.168.1.21` with mask `255.255.255.0`. The actual range may be `192.168.0.x`, `192.168.10.x`, or `10.x.x.x`; **use what your router reports**. Internet providers generally assign the router's **WAN** address; `192.168.x.x` and `10.x.x.x` are private LAN ranges. `192.168.1.0` is normally the *network address* for a `/24` LAN and is not a PC address; `.1` is often the router, but check rather than assume. Do not assign duplicate addresses.
5. From Laptop B, run `ping <Laptop-A-Ethernet-IPv4>`. From Laptop A, ping Laptop B. Replies suggest basic connectivity. A timeout can also mean Windows is blocking ping; check both PCs show the same subnet and then use an application-port test when the server exists. **Ping does not prove LifeLink or the database works.**

| Record this locally | Laptop A — Admin/server | Laptop B — Reception |
| --- | --- | --- |
| PC name | | |
| Ethernet IPv4 address | | |
| Subnet mask | | |
| Ethernet gateway/router address | | |
| Ethernet MAC address (from `ipconfig /all`) | | |

### If you have no usable router LAN ports

You previously proved a **direct cable** between two laptops: Laptop A `10.77.0.1`, Laptop B `10.77.0.2`, mask `255.255.255.0`, no Ethernet gateway; the temporary `http://10.77.0.1:8765/` test page opened. That proved only network reachability. For a third PC, add a switch/router with enough LAN ports. Do not treat the temporary HTTP probe as the LifeLink server or use it for patient data.

## Step 2 — Give the server a stable LAN address

After Step 1 works, open the router administration page at the **Default Gateway** address shown by `ipconfig`. Use the router's own label/manual for its administrator login; change a factory-default admin password privately. Find a setting named **Address Reservation**, **DHCP Reservation**, or **Static Lease**. Reserve Laptop A's **Ethernet MAC address** to an unused address in the router's actual subnet, for example `192.168.1.10` if the router is `192.168.1.1/24`. Choose an address that does not conflict with the router, another device or its DHCP pool; the router's reservation UI should help. Reconnect Laptop A's Ethernet or restart it, run `ipconfig`, and verify it received the reserved address. Leave Laptop B on automatic addressing.

If the router cannot make a DHCP reservation, record its exact LAN range and DHCP pool before choosing a manual server address outside that pool. Do **not** guess an address or change router DHCP settings while the network is working. When we reach this point, the actual router details will determine the safe fallback.

An IP reservation keeps the server findable; it is **not authentication or encryption**. The clinic app will eventually use a stable **HTTPS** address, preferably a clinic-only DNS name. If using an IP in the URL, its TLS certificate must explicitly cover that IP. Never disable certificate checking to make an address work.

## Step 3 — What to download, on which PC, and when

**For the cable/IP test: download nothing.** Windows `ipconfig`, `ping`, and later PowerShell `Test-NetConnection` are sufficient.

**For the proposed synthetic clinic-server pilot, only on Laptop A:**

1. Download **Docker Desktop for Windows** from the [official Docker installation page](https://docs.docker.com/desktop/setup/install/windows-install/). Check the Windows/WSL 2 requirements there first. Install using its normal installer, restart if prompted, launch Docker Desktop and wait until the engine is running. In PowerShell, verify `docker version` and `docker compose version`. Do not download Docker from an unofficial mirror.
2. Download **Git for Windows** from the link in the [official Supabase Docker guide](https://supabase.com/docs/guides/self-hosting/docker), if Git is not already present. Verify `git --version`. You do not need Git on the Reception laptop to run a packaged LifeLink app.
3. **Do not yet run `supabase start` or install a bare PostgreSQL server as the clinic backend.** The former is a development stack, and the latter lacks LifeLink's expected Auth/API/functions. The self-hosted [Supabase Docker deployment](https://supabase.com/docs/guides/self-hosting/docker) requires generated clinic-only credentials, URL/TLS configuration, network restrictions, LifeLink schema migrations, Edge Functions, test identities, and backup procedures. Developer/IT work must prepare and validate those as a unit before staff clients connect. Never paste the hosted project's secrets into a local `.env` or into the Flutter app.
4. The Windows **clinic client** is built on the development PC using `flutter build windows --release --dart-define=LIFELINK_CLINIC_BUILD=true`, after the clinic server exists. Copy the **entire** release folder, including `data/` and DLL files, to each staff PC. On first launch it asks for the **same trusted HTTPS clinic URL and clinic publishable key** on every staff PC; each staff member then signs in with **their own** clinic account. The ordinary cloud build does not become a LAN client by typing an IP somewhere else. See [current client implementation](CLINIC_LAN_IMPLEMENTATION_2026-10-23.md).
5. Do not download or configure a CBC analyzer driver until its exact model, export protocol, and vendor interface instructions are known. Manual lab entry remains the supported path.

## Step 4 — Server security checklist before opening the clinic app

This is an **implementation gate**, not a claim that these features are already deployed.

- Deploy the LifeLink schema, role/RLS rules, RPC functions and required Edge Functions on the clinic Supabase instance. Confirm a clean database can be brought up reproducibly. Local clinic Auth accounts are separate from the hosted cloud accounts; create distinct synthetic Admin and Reception accounts for the first test.
- Put an HTTPS reverse proxy in front of the clinic API and configure the client-trusted certificate and server URL. Supabase's [HTTPS guide](https://supabase.com/docs/guides/self-hosting/self-hosted-proxy-https) describes the production requirement. Protect the certificate key and clinic server secrets on Laptop A only.
- Allow staff PCs to reach only the clinic API (normally TCP 443) through Windows/router firewalls. Keep PostgreSQL `5432`, Studio, Docker/admin endpoints, backup storage and other internal services inaccessible from staff/guest networks and the public internet. Do not create router port forwards or DMZ rules for the clinic server. The Wi-Fi guest network must be separate.
- Give each staff person a separate, least-privilege account; verify an inactive account cannot continue using clinical functions under the server's session policy. Do not share one Admin login among PCs.
- Encrypt the server disk and backups, protect a backup copy outside Laptop A, and practise a restore on a spare machine. Keep Windows, Docker and the server stack patched. A UPS is recommended; when Laptop A sleeps, reboots, or loses power, the clinic service stops.

### How LifeLink's schema must be installed

**Do not paste the SQL files in `supabase/migrations/` into a fresh server yet.** The repository has later security and feature migrations but does **not** have a complete baseline for a blank database. Some earlier changes were made directly in the hosted project. Applying those later files blindly will fail or produce a different database. This is a developer task before the clinic-server pilot, not a step for an operator to improvise in the SQL editor.

1. **Preserve the hosted project.** Take an access-controlled schema-only export and record its current migration history. Do not export real patient rows or Auth credentials into this pilot. Confirm the export contains custom tables, columns, RLS policies, grants, functions, triggers and required storage configuration. Review Supabase's [existing-project local workflow](https://supabase.com/docs/guides/local-development/cli-workflows) and [migration-history guidance](https://supabase.com/docs/guides/deployment/database-migrations). Keep database passwords out of commands, logs and Git.
2. **Reconstruct a clean baseline migration.** Compare the export with every committed migration in timestamp order. Identify which objects predate the first committed migration and which remote-only edits must be captured. Resolve duplicate or conflicting definitions. Do not use `migration repair` merely to make warning messages disappear: it changes migration *history*, not the actual schema.
3. **Test on a disposable, isolated Supabase instance.** Apply the baseline, then later migrations in their proper order. Deploy the required Edge Functions and set clinic-only server secrets. Verify the complete schema and function behavior, including Auth-related triggers, RLS role restrictions, `queue_visit`, `complete_lab_visit`, and staff provisioning. Run the repository SQL security/sync tests in a transaction or test database and confirm rollback. Test a backup and restore onto a second disposable instance.
4. **Only then initialize the actual clinic server** using the verified versioned migration chain. Record applied migration versions and a schema fingerprint. Create synthetic clinic accounts and compare their access with the hosted behavior. Keep the hosted project unchanged during this preparation. A schema export is not an automatic account or data migration.
5. For later changes, create a **new versioned migration**, test it against a clone, back up the clinic database, apply it in a maintenance window, and verify it. Never edit an already-applied migration or manually change production tables in the Dashboard without capturing and reconciling that change in migration history.

## Step 5 — First two-PC LifeLink test, after Step 4 is complete

1. On Laptop A and Laptop B, install the **clinic** Windows build. Enter the **same** clinic HTTPS URL and clinic publishable key. Verify the setup health check succeeds on both. Do not enter a database password or `service_role`/secret key.
2. Sign in as separate synthetic Admin and Reception users. Reception issues a **synthetic** visit/token. Confirm the app reports the server commit. On Laptop A, Admin refreshes its view and sees the same visit; verify exactly one database row exists. Then test a Lab account on Laptop B (sign out of Reception), or add a third laptop later. Refresh Lab and confirm the queue shows the token. Record a synthetic lab result and confirm Admin sees it.
3. Repeat a quick click/retry to confirm no duplicate visit/result. Restart the Reception app and confirm its view rehydrates from the server. Restart the server and confirm both clients reconnect safely; no clinical action should silently pretend success while the server is down.
4. For an **internet-outage** test, disconnect **only the router WAN/ISP cable**, while leaving router power, both LAN cables and server power on. If Laptop A also has independent Wi-Fi internet, turn that Wi-Fi off for the outage test. Keep the LAN connected. Repeat synthetic Reception-to-Lab/Admin actions and confirm they commit to the local server. Reconnect internet later. A successful LAN test does **not** yet prove cloud sync.
5. The **clinic-to-hosted-Supabase bridge remains to be built and separately tested**. Until it exists, local records will **not automatically appear on patient/donor phones** after internet returns. The bridge needs a stable clinical patient ID distinct from Auth IDs, a server-owned outbound queue, idempotent retries, explicit mobile-facing data selection, sync-lag display, conflict handling and audit logs. Do not manually copy whole clinic tables or Auth users into hosted Supabase.

## Step 6 — Add a Lab PC and then more PCs

Connect each new staff PC to an unused router **LAN** socket. If the router is full, attach a **Gigabit Ethernet switch** to one LAN socket, then connect staff PCs to the switch. Leave new clients on **automatic IPv4/DHCP**. Check with `ipconfig` that each receives a unique address in the staff LAN; do not give a client the server's reserved address. Install the same clinic release folder, enter the same HTTPS clinic URL and publishable key, and sign in with an account created for that worker's role. Repeat the queue and outage tests with Reception, Lab and Admin all signed in simultaneously. A new PC does **not** need its own database.

If a future dedicated server replaces Laptop A, restore the clinic database/backups onto it, move the clinic DNS name or IP reservation under a controlled cutover, verify certificates and client trust, then test all PCs. Never operate the old and new clinic servers as simultaneous writers.

## What to do / what not to do

| Do | Do not |
| --- | --- |
| Use the router's real LAN subnet and reserve one unique server address | Assume `192.168.1.0` is a usable PC address or duplicate an IP |
| Keep router, cables and server powered during WAN outages | Assume LAN still works if the router or server is off |
| Use the authenticated HTTPS clinic API | Connect Flutter directly to PostgreSQL or expose `5432` |
| Keep clinic secrets on the server; put only a publishable key in the client | Share passwords/codes or build a service/secret key into the app |
| Test with synthetic patients and restore backups | Use real patient records before security and clinical release gates pass |
| Treat each staff PC as a client of one authoritative server | Share an Isar/SQLite database file over Windows file sharing |
| Verify local operation and cloud publication as **separate** tests | Assume returning internet automatically sends local work to phones |

## Troubleshooting in the correct order

1. **No Ethernet link:** check router power, cable, LAN socket and `ipconfig` for `Media disconnected`.
2. **`169.254.x.x`:** router DHCP did not answer; check automatic IPv4, router DHCP setting, and cable. This is not a Supabase error.
3. **PCs have different subnets:** verify both use staff LAN ports, not WAN or guest Wi-Fi; renew Ethernet DHCP after fixing the connection.
4. **Ping fails:** check addresses and Windows network/firewall profile; ping can be blocked. Once an HTTPS server exists, from Reception run `Test-NetConnection <server-address> -Port 443` in PowerShell.
5. **Port 443 fails:** check clinic server power, Docker/proxy health, server IP reservation, and firewall rules. Do not open PostgreSQL as a workaround.
6. **Port 443 works but LifeLink says certificate/auth error:** use the exact configured HTTPS name/IP, check certificate trust and clinic account/role. Do not turn off TLS verification.
7. **Token missing on another PC:** verify both are running the **clinic build**, use the **same clinic URL**, have different valid staff accounts, and refresh Lab/Admin. Inspect server transaction/audit status. The ordinary cloud build is a different backend.
8. **WAN returns but phone is stale:** check the bridge's queue, retries, last-sync time and conflict state **once that bridge has been implemented**. At present, there is no such bridge to troubleshoot.

## Milestones and honest completion criteria

| Milestone | Evidence required | Current status |
| --- | --- | --- |
| Two laptops share router LAN | Ethernet addresses in same subnet; connection test | To perform with your router |
| Clinic server installed | HTTPS health, Auth, LifeLink migrations/functions, roles, backup/restore | Not done |
| Staff share records without WAN | Reception token appears in Lab/Admin; result commits once | Not done |
| Cloud/mobile sync after WAN returns | One approved event appears once on correct mobile account; lag/conflict visible | Not built |
| Real-patient use | All [release gates](PUBLIC_RELEASE_GATE.md) and clinical/operator sign-off | Not approved |

The immediate action is **Step 1**: connect both laptops to router LAN sockets, set Ethernet IPv4/DNS to automatic, and record only their Ethernet IPv4 addresses plus the router model/LAN-port count. Those facts determine the exact server address and next installation step.
