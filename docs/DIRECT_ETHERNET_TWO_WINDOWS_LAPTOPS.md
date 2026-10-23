# Direct Ethernet test: two Windows laptops, no router

This is a **synthetic-data network check**, not a LifeLink clinic-server installation. As of 2 October 2026, this workspace laptop is the intended test server. Its physical `Ethernet` adapter has `10.77.0.1/24` with no gateway; Wi-Fi remains separate for internet. A temporary test page listens only on `10.77.0.1:8765`, and a Windows Firewall rule allows only `10.77.0.2` to reach it. The page contains no patient data. The helper is not configured to restart automatically. If the page later stops responding, on the **first laptop** open PowerShell and run `python "$env:TEMP\lifelink_lan_probe.py"`; leave that PowerShell window open during the test and press **Ctrl+C** when finished.

## On the other Windows laptop

1. Confirm the Ethernet cable is connected to the first laptop.
2. Press **Windows + R**, type `ncpa.cpl`, and press Enter.
3. Right-click **Ethernet** → **Properties** → **Internet Protocol Version 4 (TCP/IPv4)** → **Properties**.
4. Select **Use the following IP address**. Enter IP address `10.77.0.2` and subnet mask `255.255.255.0`. Leave default gateway and DNS empty. Click **OK** twice.
5. In a browser, open **http://10.77.0.1:8765/**. The expected response is `LifeLink LAN test OK. No patient data is served.` Type `http://` explicitly; this test page does not use HTTPS because it carries no clinical data.
6. If the page does not open, run `ipconfig` on the second laptop. Its **Ethernet** adapter should show `10.77.0.2`; Wi-Fi may show a different address. Confirm the cable lights/link and that the page remains available on the first laptop. A failed `ping` alone is inconclusive because Windows Firewall may block ICMP.

There is **no router or DHCP server** on this cable. Windows gave the first laptop a `169.254.x.x` address before manual configuration; that is normal when DHCP is missing. A direct cable links only two computers. To add a third staff computer, use an Ethernet switch and assign another distinct address such as `10.77.0.3/24`, or later add a router/DHCP server.

## What this does and does not prove

It proves the two laptops can exchange a message over the cable while Wi-Fi/internet is unavailable. It does **not** make LifeLink's reception, lab or admin data share automatically. The current app points to hosted Supabase by default. Its local Isar database must not be opened across a shared Windows folder. A shared, authenticated clinic API/database, staff build, encrypted storage, and later cloud synchronization still need to be implemented; see [CLINIC_LAN_SETUP_ROADMAP.md](CLINIC_LAN_SETUP_ROADMAP.md).

## Cleanup or return to automatic addressing

The probe is temporary and may stop when this laptop restarts. When the test is finished, remove the firewall rule named `LifeLink temporary LAN probe` and stop its Python process. The temporary script is at `%TEMP%\lifelink_lan_probe.py`. To return either laptop to ordinary router-based Ethernet later, reopen IPv4 Properties and choose **Obtain an IP address automatically** and **Obtain DNS server address automatically**. Do this when a router/DHCP server is available; otherwise Windows will again use a `169.254.x.x` address.
