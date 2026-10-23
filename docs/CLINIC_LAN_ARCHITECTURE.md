# Proposed clinic LAN architecture (client foundation only)

LifeLink's intended clinic workflow: reception, lab and admin share one authoritative on-site clinical database over a private LAN. Their work continues during an internet outage. Patient and donor mobiles use the cloud and may be temporarily stale during an outage. The clinic server sends approved changes to the cloud when connectivity returns. **The Flutter clinic client foundation exists; the server and cloud bridge do not.** See `CLINIC_LAN_IMPLEMENTATION_2026-10-23.md`. Use synthetic data until the entire system is built and clinically/security validated.

```text
                         Internet (may fail)
                               |
                     router/firewall + Wi-Fi
                        /              \
       private clinic LAN             Supabase cloud
        |      |      |                      |
   reception  lab   admin            patient/donor mobiles
        \      |      /                     ^
          clinic server -- outbound sync --|
          API + Postgres + audit + backups
                 ^
                 |
        CBC analyzer adapter (model-specific)
```

## Data ownership

- Clinic server owns patients, staff roles, visits, specimens, lab results and blood-unit inventory. A token issued at reception is committed there and delivered to lab/admin over the LAN (database-backed event stream or short polling). Do not make each workstation a separate authority.
- Cloud holds the minimum patient/donor-facing projection needed for mobile accounts. Use an outbound clinic sync queue with immutable operation IDs, retry/idempotency, per-record versions, audit events and an explicit conflict queue. A patient mobile must not overwrite a clinic result or stock count. Design mobile requests as requests for clinic review, not direct edits to authoritative clinical records.
- Blood stock needs a **unit/bag ledger**, including unit ID, group, collection/expiry dates, screening/release status, reservation, issue, transfusion/disposal and audit trail. A single `blood_group -> volume_ml` total cannot safely settle concurrent offline clinical decisions. Have a qualified blood-bank operator define the workflow and acceptance tests.
- If the clinic server or switch is down, the LAN application is down even when internet works. Keep a UPS, encrypted tested backups, spare hardware/recovery procedure and a written paper downtime process. Restore tests matter more than merely scheduling backups.

## Physical and network setup

1. A managed clinic server (or small dedicated PC) and all staff PCs connect by Ethernet to a switch. The switch connects to a router/firewall for internet. The LAN continues to work when the ISP fails **if the server, switch, router/DHCP and their power remain available**. Put these on a UPS. A Wi-Fi access point can join clinic tablets to the same private staff network; use a separate guest network for visitors.
2. Give the server a DHCP reservation or documented static LAN address and an internal DNS name such as `lifelink.clinic.internal`. Staff apps connect to that address over HTTPS with a certificate trusted by managed staff devices. Do not dismiss certificate errors or expose Postgres/Supabase Studio directly to staff PCs or the internet.
3. Restrict server ports with the host and router firewalls. Allow the staff API from the staff VLAN only. Keep database, backup and analyzer ports restricted to the server/adapter. Give each staff member their own account and least-privilege role; server-side permissions must work without cloud Auth reachability. Define a bounded offline session policy and revoke lost/stolen devices at the clinic server.
4. Document cabling, IP/DNS, UPS runtime, administrator recovery, patching, encrypted backups and who responds to server alarms. Rehearse internet-loss and server-loss scenarios separately.

### What makes another computer see the token

The Ethernet switch transports messages; it does not copy Isar files or make separate app databases share data. Every staff app must call the **same clinic API**, which writes to **one server database**. After reception commits a token, lab and admin query/subscribe to that database through the API. Never place an Isar or SQLite database file on a Windows shared drive for multiple computers to open.

For a synthetic-data pilot, the smallest deployment using this codebase is a properly configured self-hosted Supabase project on a dedicated clinic server. Adapt and apply the repository's schema migrations and functions to that project, provision test staff accounts there, then build a staff app pointed at the clinic project's HTTPS URL and publishable key. All staff machines use the same clinic URL, while keeping individual logins. This demonstrates same-LAN sharing; it does **not** provide cloud/mobile synchronization or production safety. The Supabase CLI development stack is not a production server.

The app now accepts paired build-time values `LIFELINK_BACKEND_URL` and `LIFELINK_BACKEND_PUBLISHABLE_KEY`. If either is supplied, both are required; the URL must be HTTPS. For example, after the LAN server and trusted certificate exist, a **synthetic-data pilot** Windows build could use `flutter build windows --dart-define=LIFELINK_BACKEND_URL=https://lifelink.clinic.internal --dart-define=LIFELINK_BACKEND_PUBLISHABLE_KEY=YOUR_LAN_PUBLISHABLE_KEY`. The publishable key is a public client identifier; never put a service-role/secret key in a Flutter build. The default build still uses the existing hosted Supabase project. This configuration does not create a clinic server, copy accounts/data, or synchronize the clinic and cloud.

Example network only: reserve `192.168.10.10` for the clinic server; assign staff PCs addresses such as `192.168.10.21` and `.22` from the router; map a private DNS name to the server; test that staff can reach the HTTPS API with the internet cable disconnected. Do not embed these example IPs in the released app. Changing an IP or buying cables alone cannot make the existing cloud-only endpoints work offline.

## CBC analyzer connection

Do not build a generic serial parser. First obtain the **exact manufacturer, model, firmware, LIS/interface manual and enabled interface licence**. The analyzer may offer Ethernet TCP/HL7 or ASTM-style messages, RS-232, USB presented as a serial port, or file export; these are different integrations. Ask the vendor for an interface test mode and sample output without real patient data.

An adapter on the lab PC or clinic server receives the raw message/file, validates framing/checksums and sender, stores an immutable raw copy with provenance, maps test codes and units to a reviewed CBC schema, and matches the analyzer sample/accession barcode to the visit. Unmatched, duplicated, incomplete, flagged or out-of-range messages go to a quarantine queue. A lab technologist compares the patient/sample identity, analyzer flags, units, reference ranges and results, then explicitly approves release; only then may a result become visible to the patient. Record analyzer model, operator, times, raw message hash, correction history and approval. Manual entry remains available with independent verification. The current `CbcSerialReader` deliberately reports that integration is not configured.

## Build order and acceptance tests

1. Separate clinical patient identity from login accounts, including child patients and verified legal guardians. Introduce the blood-unit ledger and specimen/accession identifier.
2. Build the clinic API/database and staff authentication; move reception/lab/admin reads and writes from cloud Supabase calls to the clinic API. Keep one authoritative write path. Encrypt server disks/backups; manage secrets outside client builds.
3. On two real staff PCs, disconnect the internet while retaining the LAN. Confirm a receptionist can find a previously authorized patient, issue a token, and the lab/admin see it immediately; lab can record and approve a result; inventory reservation prevents double issue. Reboot a PC/server and confirm recovery.
4. Reconnect internet. Verify ordered, idempotent cloud publication, exact patient ownership, no duplicate visit/result, visible sync lag and conflict handling. Test a revoked staff account, server outage, lost client, backup restore and clock skew.
5. Add the analyzer adapter only after the device manual and bench validation. Compare a representative set of analyzer outputs against the machine printout and reviewed reference data; test malformed, duplicated and mismatched specimen messages.

This design removes the need for separate staff-device clinical databases. A workstation may cache display data for speed, but its cache must not become a second source of truth. For real patient data, all persisted caches and backups require an approved encryption/key-management and retention design.
