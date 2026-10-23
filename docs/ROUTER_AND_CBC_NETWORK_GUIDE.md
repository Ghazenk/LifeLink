# Connecting LifeLink laptops with a router or switch

**Today:** two Windows laptops are directly connected by Ethernet. The first laptop has `10.77.0.1`, the second has `10.77.0.2`, and the temporary test page at `http://10.77.0.1:8765/` opened successfully from the second laptop. This proves the **cable/network link**, not that LifeLink's clinical database is shared. The CBC analyzer is not available or identified yet; enter independently verified CBC readings manually.

## One Ethernet port per laptop is enough

Each device needs **one** Ethernet cable to a network device. You do not need a separate laptop port for reception, lab, admin or CBC. A router can connect devices through its LAN ports. If it has too few LAN ports, connect one router LAN port to an ordinary Ethernet **switch**, then plug the devices into the switch. A switch extends the LAN; it is not a second database server.

```text
internet/modem (optional)
        |
     router WAN
     router LAN ── switch (optional, adds ports)
                    ├── LifeLink server laptop
                    ├── reception laptop/PC
                    ├── lab laptop/PC
                    ├── admin PC
                    └── CBC analyzer, only if vendor confirms Ethernet LIS export
```

Do **not** plug the analyzer or staff computers into the router's **WAN/Internet** port. Do not use guest Wi-Fi for clinical devices. Do not forward clinic database ports to the internet.

## If you buy a router later: change the addresses first

1. Keep the direct-cable setup as it is until you have the router. The current `10.77.0.1`/`.2` addresses were set manually because there is no router/DHCP server.
2. On **each Windows laptop**, press **Windows + R**, type `ncpa.cpl`, Enter; right-click **Ethernet** → **Properties** → **Internet Protocol Version 4 (TCP/IPv4)** → **Properties**. Select **Obtain an IP address automatically** and **Obtain DNS server address automatically**. Save. Do this only when the router is connected and powered; otherwise the laptops will return to `169.254.x.x` addresses.
3. Connect each laptop to a router **LAN** port, or to the switch attached to a router LAN port. Power the router and switch. A router can give each laptop a different local address automatically, even if the ISP/internet is down. Run `ipconfig` on both laptops and note the **Ethernet** IPv4 addresses; they should be in the same range, such as `192.168.1.20` and `.21`. The actual range depends on the router.
4. In the router's administration page, reserve the server laptop's local address by its Ethernet MAC address, so it stays the same. The other laptops can use automatic addresses. Keep router, switch and server on a UPS so the LAN survives a brief power interruption.
5. The old `http://10.77.0.1:8765/` test address will no longer apply after DHCP changes the server address. The temporary probe and firewall rule are limited to the direct-cable test; update or remove them before a new test. Never use that HTTP probe for patient data.

## If you buy a switch but no router

Plug every laptop into the switch. Keep the server at `10.77.0.1/24`, the second laptop at `10.77.0.2/24`, and give each additional staff computer a **unique** address (`10.77.0.3`, `.4`, and so on), all with subnet mask `255.255.255.0` and no gateway. A switch alone does not assign IP addresses or provide internet. Avoid assigning the same address twice. This is fine for a small network test; a router with DHCP is easier to administer later.

## How to check when internet is turned off

For today's two-laptop test, leave both Ethernet adapters and the temporary probe running. Turn off **Wi-Fi on both laptops**, but do not unplug the Ethernet cable. From laptop two, open `http://10.77.0.1:8765/`; it should still show `LifeLink LAN test OK`. If you later use a router, disconnect only its **WAN/ISP** cable and keep the router, switch and server powered. A successful probe proves LAN connectivity only. It does not prove token/result/inventory sharing, because the clinic server and staff-app migration are not built yet.

## CBC analyzer later

Do **not** plug in an unknown CBC machine today. Find its brand/model and ask its vendor for the **LIS/interface manual** and confirmation that result export is enabled. An Ethernet socket may be for service or printer use rather than LIS output. If it supports Ethernet LIS output, the vendor/clinic IT team can give it a controlled address on the **staff/lab LAN** through a switch/router LAN port and configure its destination IP, port and protocol to a validated LifeLink adapter. If it exports over RS-232, USB or files, it will use a different adapter, often attached to the lab PC. Nothing should publish results automatically until specimen identity, units, flags and readings are checked by lab staff. Manual verified entry remains the supported workflow now.

## What still must be built

The current LifeLink desktop app still uses hosted Supabase by default. A shared LAN clinical server, separate clinic staff build, offline staff authentication, synchronized lab queue, inventory ledger, encrypted storage/backups and outbound mobile-cloud sync remain [release work](PUBLIC_RELEASE_GATE.md). Plugging in a router or switch will not by itself make reception tokens appear in lab while the internet is off. Use synthetic data for these network experiments.
