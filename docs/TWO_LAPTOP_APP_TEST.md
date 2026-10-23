# What to expect on two LifeLink laptops today

Use synthetic test accounts and no real patient records. Both laptops must run a default LifeLink build pointing to the same hosted Supabase project. The Ethernet cable is not used for LifeLink record sharing yet.

**Observed 2 October 2026:** the operator reported that a synthetic transfusion token issued in reception on laptop one appeared in the lab queue on laptop two with internet available. This verifies that particular online handoff in the operator's environment. It does not verify WAN-off handoff, lab result posting, inventory, or clinical safety.

## Test A: donor registration (internet required)

1. With internet working, register a synthetic donor in LifeLink and complete email verification.
2. Sign in as reception on the other laptop. Open pending account approvals and approve that donor. The donor is then eligible to appear in reception's active-donor lookup.
3. A lab user does not receive a visit merely because a donor registered. Reception must issue a **donation** token for that active donor first.

## Test B: patient transfusion token (internet required)

1. Use a synthetic, active **patient** account. On laptop one, sign in as reception, open **Transfusion**, find the patient and issue a token. The dialog initially says the token was saved on this device.
2. Open the cloud/sync icon on reception and tap **Sync now**. Wait for **Up to date**. If it says pending or needs attention, the lab must not assume the visit exists in the cloud.
3. On laptop two, sign in with a separate **lab** account. In the updated build, the open lab screen syncs immediately and then every 30 seconds while visible. Tap **Sync lab queue** to pull sooner. The new waiting token should appear after the cloud accepts it and lab pulls it. In an older installed build, leave and reopen the lab screen or minimize and restore the app.
4. Enter only synthetic/verified test readings. Confirm the result syncs exactly once and the patient-facing record is correct before relying on the workflow.

## Internet-off test

The temporary `http://10.77.0.1:8765/` page should still open over Ethernet after Wi-Fi is turned off. The current LifeLink app cannot do the same cross-laptop clinical workflow offline: donor registration, patient lookup and approvals require cloud access; a visit created on reception stays on that device until cloud sync; lab cannot pull it over the direct cable. This requires the clinic LAN server described in [CLINIC_LAN_SETUP_ROADMAP.md](CLINIC_LAN_SETUP_ROADMAP.md).

The app's **Settings → Connection** shows the backend host and latest sync status. The default build displays the hosted cloud backend. This is informational; switching to a clinic backend requires deploying a real HTTPS server and building clients with its endpoint and publishable key. Do not enter the temporary Ethernet test URL as a backend.

If an online token does not appear, first check that both laptops have internet, use different reception/lab accounts, and confirm reception's sync status is **Up to date**. Reopen or refresh the lab screen. Record the exact sync status/error without sharing passwords or patient details. Do not create repeated tokens as a troubleshooting step; retries could create duplicate visits.
