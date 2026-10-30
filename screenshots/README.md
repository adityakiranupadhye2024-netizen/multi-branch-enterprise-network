# Multi-Branch Enterprise Network — Verification Screenshots

This directory contains real, high-resolution working screenshots captured directly from the live Docker emulation and packet capture environment of the **Secure Multi-Branch Enterprise Network**. Each screenshot validates an essential operational milestone spanning infrastructure provisioning, dynamic routing convergence, high-availability path selection, inter-branch connectivity, centralized application delivery, and zero-trust security policy enforcement.

---

## Screenshot Gallery & Detailed Explanations

### Screenshot 1: Docker Container Health & Infrastructure Inventory
![Screenshot 1: Docker Container Health](screenshot_01_docker_health.png)

- **Target Component:** Full Containerized Topology (`docker-compose.yml`)
- **Execution Command:** `docker compose ps`
- **Description:**  
  Demonstrates that all 18 network nodes and services are active (`Up`) across 14 isolated Docker bridge networks:
  - **3 Routing Engines:** `lab-hq`, `lab-br1`, and `lab-br2` running FRRouting (FRR 10.7.1) with Zebra and OSPF daemons.
  - **2 Centralized Services:** `lab-srv-web` (Corporate Intranet HTTP portal on Nginx/lighttpd) and `lab-srv-dhcp` (Dnsmasq DHCP service).
  - **10 Departmental PC Workstations:** Alpine Linux endpoints representing HR, Finance, and IT workstations across HQ and both branch offices, plus Admin in HQ.
  - **3 Passive Packet Capture Probes:** `lab-capture`, `lab-capture-hq`, and `lab-capture-br2` streaming unbuffered `.pcap` files.

---

### Screenshot 2: HQ Core Router OSPF Neighbors
![Screenshot 2: HQ Core Router OSPF Neighbors](screenshot_02_hq_ospf_neighbors.png)

- **Target Component:** HQ Router (`lab-hq`) OSPF Process
- **Execution Command:** `docker exec lab-hq vtysh -c "show ip ospf neighbor"`
- **Description:**  
  Confirms that the HQ Core Router (Router ID `1.1.1.1`) has successfully formed two bidirectional OSPF Area 0 adjacencies over point-to-point `/30` WAN subnets:
  - Neighbor `2.2.2.2` (Branch 1 Router) reachable via `eth4` (`10.10.10.2`) in `Full/DR` state.
  - Neighbor `3.3.3.3` (Branch 2 Router) reachable via `eth5` (`10.10.10.6`) in `Full/DR` state.
  Dead timers count down from 40 seconds and reset every 10 seconds upon receipt of periodic OSPF Hellos, proving stable link keepalives.

---

### Screenshot 3: Branch 1 & Branch 2 OSPF Neighbors (Full-Mesh WAN)
![Screenshot 3: Branch 1 & Branch 2 OSPF Neighbors](screenshot_03_branches_ospf_neighbors.png)

- **Target Component:** Remote Branch Routers (`lab-br1` & `lab-br2`)
- **Execution Commands:**  
  `docker exec lab-br1 vtysh -c "show ip ospf neighbor"`  
  `docker exec lab-br2 vtysh -c "show ip ospf neighbor"`
- **Description:**  
  Validates a complete full-mesh WAN routing architecture. Both remote sites maintain active adjacencies with the HQ hub (`1.1.1.1`) as well as a direct peer-to-peer adjacency between Branch 1 (`2.2.2.2`) and Branch 2 (`3.3.3.3`) over the dedicated inter-branch WAN link `10.10.10.8/30`. This topology guarantees direct inter-branch communication without congesting the HQ core link and eliminates HQ as a single point of failure.

---

### Screenshot 4: OSPF Routing Table with Equal-Cost Multi-Path (ECMP)
![Screenshot 4: OSPF Routing Table with ECMP](screenshot_04_ospf_ecmp_routing.png)

- **Target Component:** HQ Core Forwarding Information Base (FIB)
- **Execution Command:** `docker exec lab-hq vtysh -c "show ip route ospf"`
- **Description:**  
  Illustrates OSPF Equal-Cost Multi-Path (ECMP) routing in action. The route to the inter-branch WAN subnet `10.10.10.8/30` displays two distinct next-hops with equal administrative distance and metric `[110/20]`:
  - `via 10.10.10.2, eth4, weight 1` (path through Branch 1)
  - `via 10.10.10.6, eth5, weight 1` (path through Branch 2)  
  Traffic destined for this network is concurrently load-balanced across both WAN uplinks, providing instantaneous sub-second failover in the event of an interface outage.

---

### Screenshot 5: Inter-Branch Connectivity (Ping HQ to Branch 2)
![Screenshot 5: Inter-Branch Ping](screenshot_05_inter_branch_ping.png)

- **Target Component:** Cross-Site End-to-End Data Plane
- **Execution Command:** `docker exec lab-pc-hq-hr ping -c 3 192.168.21.100`
- **Description:**  
  Demonstrates round-trip ICMP reachability from an HQ Human Resources PC (`192.168.1.100`) to a remote Branch 2 Human Resources PC (`192.168.21.100`):
  - **0% packet loss** across 3 transmitted probe packets.
  - **TTL decrement:** Packets leave the client with TTL 64 and arrive back with `ttl=62`, verifying that packets travers two router hops (HQ Core Gateway and Branch 2 Gateway) before delivery.

---

### Screenshot 6: Central Corporate Intranet Web Portal Access
![Screenshot 6: Intranet Web Portal Access](screenshot_06_intranet_web_portal.png)

- **Target Component:** Centralized Web Server (`192.168.5.20`)
- **Execution Command:** `docker exec lab-pc-br1-hr wget -qO- http://192.168.5.20`
- **Description:**  
  Confirms application-layer reachability from a remote branch client (`lab-pc-br1-hr` on `192.168.11.100`) to the centralized corporate intranet web server located in the HQ Server Farm (`192.168.5.20`). The HTTP GET request successfully retrieves the portal document with the page title `<title>Enterprise Multi-Branch Intranet</title>` and styled metadata cards.

---

### Screenshot 7: Cisco Extended ACL Policy Enforcement (Allowed vs. Blocked)
![Screenshot 7: Cisco Extended ACL Enforcement](screenshot_07_security_acl_enforcement.png)

- **Target Component:** Firewall & Access Control Lists (`iptables` / Cisco Extended ACLs)
- **Execution Commands:**  
  `docker exec lab-pc-hq-hr ping -c 2 192.168.3.100` *(Permitted: HR to IT)*  
  `docker exec lab-pc-hq-hr ping -c 2 -W 1 192.168.2.100` *(Blocked: HR to Finance)*
- **Description:**  
  Verifies strict department-level zero-trust network segmentation:
  - **Permitted Traffic:** Routine inter-VLAN communication between HR (`192.168.1.100`) and IT (`192.168.3.100`) succeeds with 0% packet loss.
  - **Blocked Traffic:** An unauthorized attempt by HR to probe the confidential Finance subnet (`192.168.2.100`) is dropped at the router gateway by ACL rule `BLOCK_HR_TO_FINANCE`, resulting in 100% packet loss and verified DROP hit counters in the kernel table.

---

### Screenshot 8: Automated Verification Test Suite Execution
![Screenshot 8: Automated Verification Test Suite](screenshot_08_automated_test_suite.png)

- **Target Component:** Verification Harness (`test_connectivity.sh`)
- **Execution Command:** `./test_connectivity.sh`
- **Description:**  
  Displays the complete test execution summary covering all five validation suites:
  1. OSPF Adjacencies on /30 point-to-point links (Full states).
  2. Cross-site multi-branch host connectivity.
  3. HQ central intranet web server accessibility.
  4. Extended ACL policy filtering rules across all three sites.
  5. Live Wireshark packet capture streaming status.  
  Concludes with the benchmark banner:  
  `CONNECTIVITY & SECURITY DEMONSTRATION COMPLETE: ALL TESTS PASSED`.

---

### Screenshot 9: Wireshark OSPF Hello Packet Dissection
![Screenshot 9: Wireshark OSPF Hello Packet](screenshot_09_wireshark_ospf_hello.png)

- **Target Component:** Wireshark Packet Inspection (`captures/branch1-all.pcap`)
- **Display Filter:** `ospf`
- **Description:**  
  Provides deep packet inspection of OSPFv2 Hello packets transmitted over the WAN:
  - **Destination IP:** All OSPF Routers multicast address `224.0.0.5`.
  - **OSPF Header:** Version 2, Message Type 1 (Hello Packet), Packet Length 44, Router ID `3.3.3.3`, Area ID `0.0.0.0` (Backbone).
  - **Hello Parameters:** Network Mask `255.255.255.252` (/30 point-to-point WAN), Hello Interval `10s`, Dead Interval `40s`, and router priority `1`.

---

### Screenshot 10: Wireshark TCP 3-Way Handshake & HTTP GET Transaction
![Screenshot 10: Wireshark HTTP Handshake](screenshot_10_wireshark_http_handshake.png)

- **Target Component:** Wireshark Packet Inspection (`captures/http-test.pcap`)
- **Display Filter:** `http || tcp.port == 80`
- **Description:**  
  Dissects the transport and application layers for cross-branch intranet traffic:
  - **Packets 1, 3, 5:** Classic RFC 793 Transmission Control Protocol 3-Way Handshake (`[SYN]` -> `[SYN, ACK]` -> `[ACK]`) initiated from Branch 1 HR (`192.168.11.100:53186`) to HQ Web Server (`192.168.5.20:80`).
  - **Packet 7:** Client HTTP `GET / HTTP/1.1` request with `Flags: 0x018 (PSH, ACK)` and host header `192.168.5.20`.
  - **Packet 11:** Central server response delivering `HTTP/1.1 200 OK (text/html)` containing the corporate portal payload.

