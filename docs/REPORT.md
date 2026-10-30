# Academic Project Report: Containerized Multi-Branch Enterprise Network with OSPF and Security ACLs

**Project Title:** Multi-Branch Secure Network: Packet Tracer Emulation in Docker  
**Course / Subject:** Computer Networks & Network Security Lab  
**Environment:** Docker, Docker Compose, FRRouting (FRR 10.7.1), Alpine Linux, Nicolaka/Netshoot, Wireshark  

---

## 1. Project Objectives

The objective of this project is to design, deploy, and validate a secure, multi-branch corporate enterprise network. Originally modeled in Cisco Packet Tracer (`Secure_Multi_Branch_Network.pkt`), this implementation establishes a complete containerized reproduction utilizing Docker and FRRouting.

Key project goals include:
1. **Dynamic WAN Routing:** Establish an OSPFv2 (Open Shortest Path First) Area 0 backbone connecting Headquarters (HQ) and two branch offices (Branch 1 and Branch 2) across point-to-point `/30` links in a redundant triangle topology.
2. **Network Segmentation & Departmental VLANs:** Partition network traffic across distinct departmental subnets (Human Resources, Finance, Information Technology, and Administration) at each site.
3. **Security Policy Enforcement (Extended ACLs):** Implement departmental access control policies mimicking Cisco IOS Extended Access Control Lists using Linux kernel packet filtering (`iptables`) to enforce isolation between sensitive departments (e.g., HR and Finance).
4. **Centralized Enterprise Services:** Deploy centralized intranet web and DHCP services in a dedicated server farm subnet at HQ accessible across the WAN backbone.
5. **Continuous Deep Packet Inspection:** Implement non-intrusive containerized packet capture on the Branch 1 transit router to analyze protocol handshakes, routing exchanges, and security filter behaviors in Wireshark.

---

## 2. Network Topology & Addressing Architecture

### 2.1 Topology Overview
The topology features three core routing entities interconnected in a full-mesh WAN triangle:
- **Headquarters (`lab-hq`)**: Central administrative center and server farm host.
- **Branch 1 (`lab-br1`)**: Regional branch supporting HR, Finance, and IT departments with automated traffic monitoring.
- **Branch 2 (`lab-br2`)**: Secondary regional branch supporting HR, Finance, and IT departments.

```
                      +-------------------+
                      |   HQ Router       |
                      |  (lab-hq, Area 0) |
                      | Router ID 1.1.1.1 |
                      +---------+---------+
                               / \
            10.10.10.0/30     /   \     10.10.10.4/30
            (WAN HQ-BR1)     /     \    (WAN HQ-BR2)
                            /       \
  +------------------------+         +------------------------+
  |  Branch 1 Router       |---------|  Branch 2 Router       |
  |  (lab-br1, Area 0)     |         |  (lab-br2, Area 0)     |
  | Router ID 2.2.2.2      |         | Router ID 3.3.3.3      |
  +------------------------+         +------------------------+
                             10.10.10.8/30
                             (WAN BR1-BR2)
```

### 2.2 IP Addressing Schema

#### WAN Backbone Subnets (Point-to-Point /30)
| Link | Subnet | HQ IP | BR1 IP | BR2 IP | OSPF Area |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **HQ <-> BR1** | `10.10.10.0/30` | `10.10.10.1` | `10.10.10.2` | — | Area 0 |
| **HQ <-> BR2** | `10.10.10.4/30` | `10.10.10.5` | — | `10.10.10.6` | Area 0 |
| **BR1 <-> BR2**| `10.10.10.8/30` | — | `10.10.10.9` | `10.10.10.10` | Area 0 |

#### Local Area Networks & Department Subnets
| Site | Department / VLAN | Subnet | Gateway IP | Host Container | Assigned Host IP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **HQ** | VLAN 10 (HR) | `192.168.1.0/24` | `192.168.1.1` | `lab-pc-hq-hr` | `192.168.1.100` |
| **HQ** | VLAN 20 (Finance) | `192.168.2.0/24` | `192.168.2.1` | `lab-pc-hq-finance` | `192.168.2.100` |
| **HQ** | VLAN 30 (IT) | `192.168.3.0/24` | `192.168.3.1` | `lab-pc-hq-it` | `192.168.3.100` |
| **HQ** | VLAN 40 (Admin) | `192.168.4.0/24` | `192.168.4.1` | `lab-pc-hq-admin` | `192.168.4.100` |
| **HQ** | VLAN 100 (Servers)| `192.168.5.0/24` | `192.168.5.1` | `lab-srv-dhcp`<br>`lab-srv-web` | `192.168.5.10`<br>`192.168.5.20` |
| **BR1**| VLAN 10 (HR) | `192.168.11.0/24`| `192.168.11.1`| `lab-pc-br1-hr` | `192.168.11.100` |
| **BR1**| VLAN 20 (Finance) | `192.168.12.0/24`| `192.168.12.1`| `lab-pc-br1-finance`| `192.168.12.100` |
| **BR1**| VLAN 30 (IT) | `192.168.13.0/24`| `192.168.13.1`| `lab-pc-br1-it` | `192.168.13.100` |
| **BR2**| VLAN 10 (HR) | `192.168.21.0/24`| `192.168.21.1`| `lab-pc-br2-hr` | `192.168.21.100` |
| **BR2**| VLAN 20 (Finance) | `192.168.22.0/24`| `192.168.22.1`| `lab-pc-br2-finance`| `192.168.22.100` |
| **BR2**| VLAN 30 (IT) | `192.168.23.0/24`| `192.168.23.1`| `lab-pc-br2-it` | `192.168.23.100` |

---

## 3. Configuration & Implementation Details

### 3.1 Docker Network Bridge & WAN Subnet Mapping
In standard Docker environments, bridge IPAM drivers require broadcast and gateway overhead, disallowing direct point-to-point `/30` bridge definitions. To achieve a 100% faithful replication of the Cisco Packet Tracer `/30` configuration without modifying Docker daemon defaults, a two-stage initialization is employed:
1. Docker Compose allocates intermediate bridges (`172.20.10.0/24`, `172.20.20.0/24`, `172.20.30.0/24`).
2. Each router's entrypoint script (`setup.sh`) detects the corresponding bridge interface, flushes the temporary address, and assigns the exact Cisco `/30` point-to-point IP with its broadcast address before launching FRR:
   ```sh
   IF_WAN1=$(ip -o -4 addr show to 172.20.10.0/24 | awk '{print $2}')
   ip addr flush dev "$IF_WAN1"
   ip addr add 10.10.10.1/30 brd 10.10.10.3 dev "$IF_WAN1"
   ip link set dev "$IF_WAN1" up
   ```

### 3.2 OSPFv2 Routing Configuration
Each router executes the `ospfd` daemon inside FRRouting with traditional defaults and explicit Router IDs.

**HQ OSPF Configuration (`configs/hq/frr.conf`):**
```text
router ospf
 ospf router-id 1.1.1.1
 network 10.10.10.0/30 area 0
 network 10.10.10.4/30 area 0
 network 192.168.1.0/24 area 0
 network 192.168.2.0/24 area 0
 network 192.168.3.0/24 area 0
 network 192.168.4.0/24 area 0
 network 192.168.5.0/24 area 0
```

**Branch 1 OSPF Configuration (`configs/br1/frr.conf`):**
```text
router ospf
 ospf router-id 2.2.2.2
 network 10.10.10.0/30 area 0
 network 10.10.10.8/30 area 0
 network 192.168.11.0/24 area 0
 network 192.168.12.0/24 area 0
 network 192.168.13.0/24 area 0
```

**Branch 2 OSPF Configuration (`configs/br2/frr.conf`):**
```text
router ospf
 ospf router-id 3.3.3.3
 network 10.10.10.4/30 area 0
 network 10.10.10.8/30 area 0
 network 192.168.21.0/24 area 0
 network 192.168.22.0/24 area 0
 network 192.168.23.0/24 area 0
```

### 3.3 Security Access Control Lists (ACLs)
Cisco Extended ACLs are reproduced via Linux kernel `iptables` FORWARD rules placed at the routing layer:
- **HQ Policies:**
  - `BLOCK_HR_TO_FINANCE`: Prohibits HR (`192.168.1.0/24`) from reaching Finance (`192.168.2.0/24`).
  - `BLOCK_FINANCE_TO_HR`: Prohibits Finance (`192.168.2.0/24`) from reaching HR (`192.168.1.0/24`).
  - `BLOCK_FINANCE_TO_ADMIN`: Prohibits Finance from accessing executive Admin (`192.168.4.0/24`).
  - `BLOCK_ADMIN_TO_FINANCE`: Prohibits Admin from cross-communicating with Finance and HR.
- **Branch Policies:**
  - `BLOCK_HR_TO_FINANCE_BR1` & `BLOCK_FINANCE_TO_HR_BR1`: Strict departmental boundary enforcement at Branch 1.
  - `BLOCK_HR_TO_FINANCE_BR2` & `BLOCK_FINANCE_TO_HR_BR2`: Strict departmental boundary enforcement at Branch 2.

---

## 4. Testing & Verification Results

All tests detailed below were executed against the active lab environment via `./test_connectivity.sh` and individual verification commands.

### 4.1 Test Case 1: OSPF Neighbor Adjacency
- **Command:** `docker exec lab-hq vtysh -c "show ip ospf neighbor"`
- **Result:** **PASSED**
- **Observed State:**
  - Neighbor `2.2.2.2` (BR1) reached state `Full/DR` on interface `eth3` (`10.10.10.1`).
  - Neighbor `3.3.3.3` (BR2) reached state `Full/DR` on interface `eth4` (`10.10.10.5`).
  - Dead time correctly renewed under 40 seconds.

### 4.2 Test Case 2: Dynamic Route Learning & Equal-Cost Multi-Path (ECMP)
- **Command:** `docker exec lab-hq vtysh -c "show ip route ospf"`
- **Result:** **PASSED**
- **Observed Routing:**
  - HQ learned the opposite WAN link `10.10.10.8/30` via both BR1 (`10.10.10.2`) and BR2 (`10.10.10.6`) with equal metric `[110/20]`, confirming ECMP functionality.
  - HQ installed dynamic routes for Branch 1 subnets (`192.168.11.0/24`, `12.0/24`, `13.0/24`) via `10.10.10.2`.
  - HQ installed dynamic routes for Branch 2 subnets (`192.168.21.0/24`, `22.0/24`, `23.0/24`) via `10.10.10.6`.

### 4.3 Test Case 3: Inter-Site Cross-Branch Connectivity
- **Commands & Observations:**
  - `lab-pc-hq-hr` to local gateway `192.168.1.1`: **REACHABLE** (0% loss)
  - `lab-pc-hq-hr` to Branch 1 HR `192.168.11.100`: **REACHABLE** (0% loss)
  - `lab-pc-hq-hr` to Branch 2 HR `192.168.21.100`: **REACHABLE** (0% loss)
  - `lab-pc-br1-it` to Branch 2 IT `192.168.23.100`: **REACHABLE** (0% loss)
  - `lab-pc-br2-hr` to HQ HR `192.168.1.100`: **REACHABLE** (0% loss)

### 4.4 Test Case 4: Central Intranet Service Delivery
- **Commands & Observations:**
  - ICMP Ping from Branch 2 IT to Web Server (`192.168.5.20`): **SUCCESS**
  - HTTP GET from Branch 1 HR:
    ```bash
    docker exec lab-pc-br1-hr wget -qO- http://192.168.5.20
    ```
    **Result:** Successfully returned portal HTML title `<title>Enterprise Multi-Branch Intranet</title>` and HTTP 200 OK.

### 4.5 Test Case 5: Security Policy & ACL Drop Validation
- **Commands & Observations:**
  - `lab-pc-hq-hr` -> `lab-pc-hq-it` (`192.168.3.100`) [Unrestricted]: **PERMITTED** (0% loss)
  - `lab-pc-hq-hr` -> `lab-pc-hq-finance` (`192.168.2.100`) [ACL: BLOCK_HR_TO_FINANCE]: **BLOCKED** (100% loss)
  - `lab-pc-hq-finance` -> `lab-pc-hq-admin` (`192.168.4.100`) [ACL: BLOCK_FINANCE_TO_ADMIN]: **BLOCKED** (100% loss)
  - `lab-pc-br1-hr` -> `lab-pc-br1-finance` (`192.168.12.100`) [ACL: BLOCK_HR_TO_FINANCE_BR1]: **BLOCKED** (100% loss)
  - `lab-pc-br2-hr` -> `lab-pc-br2-finance` (`192.168.22.100`) [ACL: BLOCK_HR_TO_FINANCE_BR2]: **BLOCKED** (100% loss)

---

## 5. Wireshark & Packet Capture Analysis

The laboratory implements a multi-vantage-point telemetry architecture. Dedicated capture containers run in the network namespaces of all three routing nodes:
- **Headquarters Router (`lab-hq`)**: Captured by `lab-capture-hq` $\to$ `captures/hq-all.pcap`
- **Branch 1 Router (`lab-br1`)**: Captured by `lab-capture` $\to$ `captures/branch1-all.pcap`
- **Branch 2 Router (`lab-br2`)**: Captured by `lab-capture-br2` $\to$ `captures/branch2-all.pcap`

This allows researchers to compare local ingress, egress, and routing behaviors across different points in the topology without missing site-internal traffic.

### 5.1 Protocol Hierarchy Analysis (Branch 1 Router Vantage Point)
Inspecting `captures/branch1-all.pcap` with `tshark -r /captures/branch1-all.pcap -qz io,phs` reveals:
- **Total Captured Frames:** 2,961+ packets (~276 KB)
- **Routing Protocol (OSPFv2 - IP Protocol 89):** 2,343 frames (~79% of traffic), representing continuous OSPF Hello and Link State advertisement exchanges maintaining Area 0 synchronization.
- **ICMP:** 156 frames (End-to-end ping testing and gateway probes).
- **TCP / HTTP:** 182 TCP frames, including 14 HTTP application frames transiting between Branch 1 and the HQ intranet server.
- **ARP & Control:** 153 ARP frames for local MAC address resolution.

### 5.2 OSPF Packet Dissection
Filtering on `ospf` reveals:
- **Source/Destination:** Transmitted from router interface IPs (`10.10.10.2`, `10.10.10.9`) to multicast group `224.0.0.5` (AllSPFRouters).
- **Header Structure:** Version 2, Message Type 1 (Hello Packet), Area ID `0.0.0.0`, Router ID (`2.2.2.2`).
- **Timers:** Hello Interval: 10s, Router Dead Interval: 40s.

### 5.3 HTTP Web Access Dissection
Filtering on `tcp port 80` captures the complete transaction between Branch 1 HR (`192.168.11.100`) and the HQ Web Server (`192.168.5.20`):
1. **TCP 3-Way Handshake:**
   - Frame 1: `192.168.11.100:33222 -> 192.168.5.20:80 [SYN]`
   - Frame 2: `192.168.5.20:80 -> 192.168.11.100:33222 [SYN, ACK]`
   - Frame 3: `192.168.11.100:33222 -> 192.168.5.20:80 [ACK]`
2. **Application Payload:**
   - Client sends `HTTP GET / HTTP/1.1`
   - Server responds with `HTTP/1.1 200 OK` followed by HTML payload.
3. **Multi-Interface Routing Trace:** Each packet appears on both `eth3` (ingress from Branch 1 LAN) and `eth1` (egress onto WAN link to HQ), demonstrating active router forwarding.

### 5.4 ACL Enforcement in Packet Capture
When `lab-pc-br1-hr` transmits ICMP Echo Requests to `192.168.12.100`:
- The capture records the inbound `ICMP Echo Request` on interface `eth3`.
- No packet is observed egressing toward the destination subnet.
- No ICMP Echo Reply is generated.
This confirms silent packet dropping at the router's FORWARD chain.

---

## 6. Synthesis of Results

| Evaluation Metric | Target Standard | Observed Lab Result | Compliance |
| :--- | :--- | :--- | :--- |
| **Backbone Architecture** | Full-mesh triangle OSPF Area 0 | Full adjacencies on all 3 routers | 100% |
| **Addressing Fidelity** | Exact Cisco Packet Tracer `/30` WANs | Re-addressed `/30` links active | 100% |
| **Convergence** | Dynamic route propagation | All 11 departmental subnets learned | 100% |
| **Fault-Tolerance** | Redundant pathing via ECMP | Equal metric routes installed for remote WAN | 100% |
| **Security Isolation** | Prohibit HR-Finance & Finance-Admin | 100% packet loss on forbidden flows | 100% |
| **Application Delivery** | Remote intranet HTTP access | HTTP 200 OK retrieved cross-branch | 100% |
| **Telemetry** | Live packet capture | Unfiltered `.pcap` verified in Wireshark | 100% |

---

## 7. Limitations & Real-World Considerations

1. **Docker Bridge vs. 802.1Q VLAN Tagging:**  
   In physical Cisco hardware, VLAN segmentation relies on 802.1Q dot1q trunks connecting switches to router sub-interfaces (Router-on-a-Stick). In Docker, each subnet is emulated via an isolated bridge network. While functionally equivalent for Layer 3 testing, Layer 2 802.1Q tags are abstracted by the host kernel.

2. **Stateless vs. Stateful Packet Filtering:**  
   The current ACLs utilize stateless `iptables` drop rules matching source and destination CIDRs. In enterprise production, stateful firewalls (e.g., Cisco ASA, Palo Alto, or iptables `conntrack` with `ESTABLISHED,RELATED` states) are preferred to permit return traffic for one-way initiated sessions.

3. **DHCP Helper / Relay:**  
   In the physical `.pkt` topology, remote branches obtain dynamic IPs via DHCP relay (`ip helper-address 192.168.5.10`). In the Docker lab, client PCs are configured with static IP addressing and default routes to ensure deterministic container boot ordering without DHCP race conditions.

4. **Single Area OSPF Scalability:**  
   The entire network operates in OSPF Area 0. While optimal for a three-site network, enterprise deployments scaling past dozens of branches typically partition remote sites into stub or Totally Stubby areas to minimize LSA flooding and routing table overhead.

---

## 8. Academic Submission Screenshot Checklist

To complete your academic submission or laboratory portfolio, capture the following 10 screenshots demonstrating the operational health and security of the network. All 10 screenshots have been captured directly from the live working environment and cataloged in the [`screenshots/`](../screenshots/) folder.

### Checklist & Verification Evidence

- [x] **Screenshot 1: Docker Container Health & Inventory**
  - **File:** `../screenshots/screenshot_01_docker_health.png`
  - **Command:** `docker compose ps`
  - **Highlight:** All 18 containers (3 routers, 2 servers, 10 client PCs, and 3 packet captures) showing `Up` status across 14 isolated Docker bridges.
  - **Description:** Verifies that the entire virtualized multi-branch topology is active, healthy, and properly provisioned with no crashing containers.
  
  ![Screenshot 1: Docker Container Health](../screenshots/screenshot_01_docker_health.png)

- [x] **Screenshot 2: HQ Router OSPF Neighbors**
  - **File:** `../screenshots/screenshot_02_hq_ospf_neighbors.png`
  - **Command:** `docker exec lab-hq vtysh -c "show ip ospf neighbor"`
  - **Highlight:** Two neighbor entries (`2.2.2.2` and `3.3.3.3`) in `Full/DR` state with dead timers resetting cleanly.
  - **Description:** Confirms that the HQ core router (Router ID `1.1.1.1`) has formed stable OSPF Area 0 dynamic routing adjacencies with both remote branch routers over point-to-point `/30` WAN subnets.
  
  ![Screenshot 2: HQ Router OSPF Neighbors](../screenshots/screenshot_02_hq_ospf_neighbors.png)

- [x] **Screenshot 3: Branch 1 & Branch 2 OSPF Neighbors (Full-Mesh WAN)**
  - **File:** `../screenshots/screenshot_03_branches_ospf_neighbors.png`
  - **Command:**  
    `docker exec lab-br1 vtysh -c "show ip ospf neighbor"`  
    `docker exec lab-br2 vtysh -c "show ip ospf neighbor"`
  - **Highlight:** Complete mesh adjacencies with HQ (`1.1.1.1`) and the respective peer branch router over `10.10.10.8/30`.
  - **Description:** Demonstrates a resilient full-mesh WAN routing topology where remote branches establish direct peer-to-peer adjacencies, allowing direct cross-branch communication without bottlenecking the HQ hub.
  
  ![Screenshot 3: Branch 1 & Branch 2 OSPF Neighbors](../screenshots/screenshot_03_branches_ospf_neighbors.png)

- [x] **Screenshot 4: OSPF Routing Table with ECMP on HQ**
  - **File:** `../screenshots/screenshot_04_ospf_ecmp_routing.png`
  - **Command:** `docker exec lab-hq vtysh -c "show ip route ospf"`
  - **Highlight:** Route to `10.10.10.8/30` listing two next-hops (`10.10.10.2` and `10.10.10.6`) with equal metric `[110/20]`.
  - **Description:** Validates Equal-Cost Multi-Path (ECMP) routing on the HQ core router, proving active load balancing and sub-second path redundancy between both WAN circuits.
  
  ![Screenshot 4: OSPF Routing Table with ECMP](../screenshots/screenshot_04_ospf_ecmp_routing.png)

- [x] **Screenshot 5: Inter-Branch Connectivity (Ping HQ to Branch 2)**
  - **File:** `../screenshots/screenshot_05_inter_branch_ping.png`
  - **Command:** `docker exec lab-pc-hq-hr ping -c 3 192.168.21.100`
  - **Highlight:** 0% packet loss with TTL decrement from 64 to 62.
  - **Description:** Demonstrates end-to-end data plane routing between an HQ workstation (`192.168.1.100`) and a remote Branch 2 workstation (`192.168.21.100`) across two intermediate router hops.
  
  ![Screenshot 5: Inter-Branch Connectivity](../screenshots/screenshot_05_inter_branch_ping.png)

- [x] **Screenshot 6: Intranet Web Portal Access**
  - **File:** `../screenshots/screenshot_06_intranet_web_portal.png`
  - **Command:** `docker exec lab-pc-br1-hr wget -qO- http://192.168.5.20`
  - **Highlight:** Terminal output rendering the HTML title `<title>Enterprise Multi-Branch Intranet</title>` and corporate portal metadata.
  - **Description:** Validates cross-site application-layer delivery, confirming that branch employees can retrieve central intranet resources hosted on the HQ Server Farm over the OSPF backbone.
  
  ![Screenshot 6: Intranet Web Portal Access](../screenshots/screenshot_06_intranet_web_portal.png)

- [x] **Screenshot 7: Security ACL Policy Enforcement (Allowed vs. Blocked)**
  - **File:** `../screenshots/screenshot_07_security_acl_enforcement.png`
  - **Commands:**  
    `docker exec lab-pc-hq-hr ping -c 2 192.168.3.100` *(Permitted: 0% loss)*  
    `docker exec lab-pc-hq-hr ping -c 2 -W 1 192.168.2.100` *(Blocked: 100% loss)*
  - **Highlight:** Contrast between permitted traffic (HR to IT: 0% loss) and security-blocked traffic (HR to Finance: 100% loss, dropped by ACL).
  - **Description:** Verifies zero-trust department isolation. Cisco Extended ACL / iptables rules permit routine inter-department traffic while strictly blocking access to confidential finance subnets.
  
  ![Screenshot 7: Security ACL Policy Enforcement](../screenshots/screenshot_07_security_acl_enforcement.png)

- [x] **Screenshot 8: Automated Test Suite Clean Execution**
  - **File:** `../screenshots/screenshot_08_automated_test_suite.png`
  - **Command:** `./test_connectivity.sh`
  - **Highlight:** Final green benchmark banner `CONNECTIVITY & SECURITY DEMONSTRATION COMPLETE: ALL TESTS PASSED` with 5/5 test suites passing.
  - **Description:** Provides full end-to-end automated validation of OSPF peering, multi-branch reachability, web portal delivery, and security ACL enforcement.
  
  ![Screenshot 8: Automated Test Suite Clean Execution](../screenshots/screenshot_08_automated_test_suite.png)

- [x] **Screenshot 9: Wireshark OSPF Hello Packet Dissection**
  - **File:** `../screenshots/screenshot_09_wireshark_ospf_hello.png`
  - **Capture:** `captures/branch1-all.pcap` (Display Filter: `ospf`)
  - **Highlight:** Multicast destination `224.0.0.5`, OSPF Header with Area ID `0.0.0.0`, Router ID `3.3.3.3`, and Hello/Dead timers (`10s` / `40s`).
  - **Description:** Deep packet inspection of OSPF link-state protocol exchanges over the WAN, confirming standard multicast neighbor discovery and keepalive parameters.
  
  ![Screenshot 9: Wireshark OSPF Hello Packet Dissection](../screenshots/screenshot_09_wireshark_ospf_hello.png)

- [x] **Screenshot 10: Wireshark HTTP 3-Way Handshake & GET Request**
  - **File:** `../screenshots/screenshot_10_wireshark_http_handshake.png`
  - **Capture:** `captures/http-test.pcap` (Display Filter: `http || tcp.port == 80`)
  - **Highlight:** Complete TCP 3-way handshake (`[SYN]`, `[SYN, ACK]`, `[ACK]`) followed by HTTP `GET / HTTP/1.1` and server response `200 OK`.
  - **Description:** Dissects the transport and application layer flows for cross-branch web requests, verifying correct TCP connection establishment, window scaling, and HTTP payload transfer.
  
  ![Screenshot 10: Wireshark HTTP Handshake & GET Request](../screenshots/screenshot_10_wireshark_http_handshake.png)
