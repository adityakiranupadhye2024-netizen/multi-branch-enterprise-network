# Multi-Branch Secure Network Lab: Demonstration & Verification Guide

This guide provides step-by-step commands to demonstrate, test, and verify the Docker-based multi-branch enterprise network lab. Every command in this guide has been verified against the active project environment.

---

## 1. Environment & Container Status

### 1.1 Check All Active Containers
The topology runs 16 containers: 3 FRRouting routers, 10 department end-user PCs, 2 central infrastructure servers (DHCP & Web/DNS), and 1 continuous packet capture container.

```bash
docker compose ps
```

**Expected Status:** All 16 containers should show `Up` status:
- Routers: `lab-hq`, `lab-br1`, `lab-br2`
- HQ Clients & Servers: `lab-pc-hq-hr`, `lab-pc-hq-finance`, `lab-pc-hq-it`, `lab-pc-hq-admin`, `lab-srv-dhcp`, `lab-srv-web`
- Branch 1 Clients: `lab-pc-br1-hr`, `lab-pc-br1-finance`, `lab-pc-br1-it`
- Branch 2 Clients: `lab-pc-br2-hr`, `lab-pc-br2-finance`, `lab-pc-br2-it`
- Capture Service: `lab-capture`

---

## 2. OSPF Dynamic Routing Verification

Each router runs FRRouting (`vtysh`) with OSPFv2 in Area 0 over point-to-point `/30` WAN links.

### 2.1 Verify OSPF Neighbor Adjacencies

Check that all three routers form full OSPF adjacencies across the triangle WAN mesh:

```bash
# Check HQ Neighbors (Expect Full adjacency with BR1 2.2.2.2 and BR2 3.3.3.3)
docker exec lab-hq vtysh -c "show ip ospf neighbor"

# Check Branch 1 Neighbors (Expect Full adjacency with HQ 1.1.1.1 and BR2 3.3.3.3)
docker exec lab-br1 vtysh -c "show ip ospf neighbor"

# Check Branch 2 Neighbors (Expect Full adjacency with HQ 1.1.1.1 and BR1 2.2.2.2)
docker exec lab-br2 vtysh -c "show ip ospf neighbor"
```

**What to look for:**
- `State`: Must display `Full/DR` or `Full/Backup`.
- `Dead Time`: Regularly resetting before expiring (~30s–40s).
- `Neighbor ID`: `1.1.1.1` (HQ), `2.2.2.2` (BR1), `3.3.3.3` (BR2).

### 2.2 Verify OSPF Routing Tables

Inspect the routes learned dynamically via OSPF (`O` routes):

```bash
# View OSPF routes on HQ
docker exec lab-hq vtysh -c "show ip route ospf"

# View OSPF routes on Branch 1
docker exec lab-br1 vtysh -c "show ip route ospf"

# View OSPF routes on Branch 2
docker exec lab-br2 vtysh -c "show ip route ospf"
```

**Key Routing Observations to Highlight in Demo:**
1. **ECMP (Equal-Cost Multi-Path):**
   - On `lab-hq`, link `10.10.10.8/30` (the WAN link between BR1 and BR2) is learned via both `10.10.10.2` (BR1) and `10.10.10.6` (BR2) with equal metric `[110/20]`.
2. **Branch Subnet Distribution:**
   - HQ learns Branch 1 subnets (`192.168.11.0/24`, `12.0/24`, `13.0/24`) via next-hop `10.10.10.2`.
   - HQ learns Branch 2 subnets (`192.168.21.0/24`, `22.0/24`, `23.0/24`) via next-hop `10.10.10.6`.
   - Branch 1 and Branch 2 learn all HQ subnets (`192.168.1.0/24` through `5.0/24`) dynamically.

---

## 3. End-to-End Connectivity & Service Access

### 3.1 Local Gateway Reachability
Verify that end-user containers can reach their default gateway router:

```bash
# HQ HR to HQ Gateway (192.168.1.1)
docker exec lab-pc-hq-hr ping -c 2 192.168.1.1
```

### 3.2 Inter-Branch Cross-Site Connectivity
Verify routing across the OSPF WAN backbone between distinct branches:

```bash
# HQ HR (192.168.1.100) -> Branch 1 HR (192.168.11.100)
docker exec lab-pc-hq-hr ping -c 2 192.168.11.100

# HQ HR (192.168.1.100) -> Branch 2 HR (192.168.21.100)
docker exec lab-pc-hq-hr ping -c 2 192.168.21.100

# Branch 1 IT (192.168.13.100) -> Branch 2 IT (192.168.23.100)
docker exec lab-pc-br1-it ping -c 2 192.168.23.100

# Branch 2 HR (192.168.21.100) -> HQ HR (192.168.1.100)
docker exec lab-pc-br2-hr ping -c 2 192.168.1.100
```

### 3.3 Central Intranet Web Portal Access
Test HTTP access to the corporate intranet hosted in HQ VLAN 100 (`192.168.5.20`):

```bash
# Branch 2 IT pinging the Web Server
docker exec lab-pc-br2-it ping -c 2 192.168.5.20

# Branch 1 HR fetching HTTP content via wget
docker exec lab-pc-br1-hr wget -qO- http://192.168.5.20
```

**Expected Result:** The command returns HTML containing `<title>Enterprise Multi-Branch Intranet</title>` and the portal dashboard.

---

## 4. Security & Access Control List (ACL) Verification

The lab replicates Cisco IOS Extended ACLs using Linux kernel `iptables` FORWARD rules to isolate sensitive departments.

### 4.1 Permitted Traffic (Baseline)
Verify that traffic between unrestricted departments passes freely:

```bash
# HQ HR (192.168.1.100) -> HQ IT (192.168.3.100) [Traffic Permitted]
docker exec lab-pc-hq-hr ping -c 2 192.168.3.100
```
**Expected Result:** 0% packet loss.

### 4.2 Blocked Traffic (ACL Enforcement)
Verify that security policies drop prohibited traffic:

```bash
# 1. HQ: HR blocked from Finance (BLOCK_HR_TO_FINANCE)
docker exec lab-pc-hq-hr ping -c 2 -W 1 192.168.2.100

# 2. HQ: Finance blocked from Admin (BLOCK_FINANCE_TO_ADMIN)
docker exec lab-pc-hq-finance ping -c 2 -W 1 192.168.4.100

# 3. Branch 1: HR blocked from Finance (BLOCK_HR_TO_FINANCE_BR1)
docker exec lab-pc-br1-hr ping -c 2 -W 1 192.168.12.100

# 4. Branch 2: HR blocked from Finance (BLOCK_HR_TO_FINANCE_BR2)
docker exec lab-pc-br2-hr ping -c 2 -W 1 192.168.22.100
```
**Expected Result:** 100% packet loss (`2 packets transmitted, 0 packets received, 100% packet loss`).

---

## 5. Automated Verification Script

Run the automated test suite that executes all OSPF checks, inter-branch ping matrices, HTTP portal verification, and ACL policy enforcement:

```bash
./test_connectivity.sh
```

**Expected Summary:**
`CONNECTIVITY & SECURITY DEMONSTRATION COMPLETE: ALL TESTS PASSED`

---

---

## 6. Multi-Router Packet Capture & Wireshark Analysis

Dedicated capture containers run in the network namespaces of all three routers and continuously write to the `./captures` directory:
- **Headquarters Router (`lab-hq`)**: Captured by `lab-capture-hq` $\to$ `captures/hq-all.pcap`
- **Branch 1 Router (`lab-br1`)**: Captured by `lab-capture` $\to$ `captures/branch1-all.pcap`
- **Branch 2 Router (`lab-br2`)**: Captured by `lab-capture-br2` $\to$ `captures/branch2-all.pcap`

### 6.1 Check Capture Files Status
```bash
ls -lh captures/
```

### 6.2 Inspect Protocol Breakdown (Protocol Hierarchy)
```bash
# Branch 1
docker exec lab-capture tshark -r /captures/branch1-all.pcap -qz io,phs

# Headquarters
docker exec lab-capture-hq tshark -r /captures/hq-all.pcap -qz io,phs

# Branch 2
docker exec lab-capture-br2 tshark -r /captures/branch2-all.pcap -qz io,phs
```

### 6.3 Inspect OSPF Hello and Routing Control Traffic
```bash
docker exec lab-capture sh -c "tshark -r /captures/branch1-all.pcap -Y 'ospf' | head -n 10"
```
Or using tcpdump:
```bash
docker exec lab-capture tcpdump -nn -r /captures/branch1-all.pcap "proto 89" -c 10
```

### 6.4 Inspect HTTP Web Transactions (3-Way Handshake & GET Request)
```bash
docker exec lab-capture tcpdump -nn -r /captures/branch1-all.pcap "tcp port 80" -c 10
```
Or using tshark:
```bash
docker exec lab-capture sh -c "tshark -r /captures/branch1-all.pcap -Y 'tcp.port == 80' | head -n 10"
```

### 6.5 Observe ACL Drops in Capture
When pinging from `lab-pc-br1-hr` to `192.168.12.100` (prohibited by ACL), inspect the capture:
```bash
docker exec lab-capture sh -c "tshark -r /captures/branch1-all.pcap -Y 'ip.dst == 192.168.12.100' | tail -n 5"
```
**Observation:** Only ICMP Echo Requests enter on the ingress interface; no forward or reply occurs because `iptables` FORWARD dropped the frame.

### 6.6 Analyzing in Desktop Wireshark
Open any of the three router capture files directly in desktop Wireshark:
```bash
# Open Headquarters Capture
open -a Wireshark captures/hq-all.pcap

# Open Branch 1 Capture
open -a Wireshark captures/branch1-all.pcap

# Open Branch 2 Capture
open -a Wireshark captures/branch2-all.pcap
```

Recommended Wireshark display filters:
- `ospf` (Displays OSPF Hellos, DB Description, LSR, LSU, LSAck)
- `http` (Displays Intranet HTTP GET and 200 OK responses)
- `icmp` (Displays ping requests, replies, and missing replies)
- `ip.addr == 10.10.10.0/24` (WAN backbone traffic)

---

## 7. Graceful Shutdown & Cleanup

When demonstration is complete:

```bash
# Stop all capture containers cleanly to flush buffers
docker compose stop capture capture-hq capture-br2

# Tear down all containers and networks
docker compose down
```
