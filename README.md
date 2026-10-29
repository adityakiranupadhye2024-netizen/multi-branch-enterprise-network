# Multi-Branch Secure Network (Packet Tracer Replica in Docker)

This lab is a faithful Docker reproduction of the Cisco Packet Tracer network in `Secure_Multi_Branch_Network.pkt`. It features 3 FRRouting routers, 10 client PCs across distinct VLAN subnets, dedicated DHCP and DNS/Web servers, OSPF Area 0 routing across point-to-point `/30` WAN links, Cisco Extended Access Control Lists (ACLs), and an automated Wireshark capture container.

---

## Topology Architecture

### 1. Routers & WAN Backbone
* **HQ Router (`lab-hq`)**:
  * WAN to BR1: `10.10.10.1/30`
  * WAN to BR2: `10.10.5/30` -> `10.10.10.5/30`
  * OSPF Router ID: `1.1.1.1` (Area 0)
* **Branch 1 Router (`lab-br1`)**:
  * WAN to HQ: `10.10.10.2/30`
  * WAN to BR2: `10.10.10.9/30`
  * OSPF Router ID: `2.2.2.2` (Area 0)
* **Branch 2 Router (`lab-br2`)**:
  * WAN to HQ: `10.10.10.6/30`
  * WAN to BR1: `10.10.10.10/30`
  * OSPF Router ID: `3.3.3.3` (Area 0)

### 2. Local Area Networks (VLANs & Subnets)
* **HQ Site (Switch2)**:
  * VLAN 10 (HR): `192.168.1.0/24` — GW `192.168.1.1` — Host `lab-pc-hq-hr` (`192.168.1.100`)
  * VLAN 20 (Finance): `192.168.2.0/24` — GW `192.168.2.1` — Host `lab-pc-hq-finance` (`192.168.2.100`)
  * VLAN 30 (IT): `192.168.3.0/24` — GW `192.168.3.1` — Host `lab-pc-hq-it` (`192.168.3.100`)
  * VLAN 40 (Admin): `192.168.4.0/24` — GW `192.168.4.1` — Host `lab-pc-hq-admin` (`192.168.4.100`)
  * VLAN 100 (Server Farm): `192.168.5.0/24` — GW `192.168.5.1`
    * DHCP Server `lab-srv-dhcp` (`192.168.5.10`)
    * DNS / Web Server `lab-srv-web` (`192.168.5.20`)
* **Branch 1 Site (Switch0)**:
  * VLAN 10 (HR): `192.168.11.0/24` — GW `192.168.11.1` — Host `lab-pc-br1-hr` (`192.168.11.100`)
  * VLAN 20 (Finance): `192.168.12.0/24` — GW `192.168.12.1` — Host `lab-pc-br1-finance` (`192.168.12.100`)
  * VLAN 30 (IT): `192.168.13.0/24` — GW `192.168.13.1` — Host `lab-pc-br1-it` (`192.168.13.100`)
* **Branch 2 Site (Switch1)**:
  * VLAN 10 (HR): `192.168.21.0/24` — GW `192.168.21.1` — Host `lab-pc-br2-hr` (`192.168.21.100`)
  * VLAN 20 (Finance): `192.168.22.0/24` — GW `192.168.22.1` — Host `lab-pc-br2-finance` (`192.168.22.100`)
  * VLAN 30 (IT): `192.168.23.0/24` — GW `192.168.23.1` — Host `lab-pc-br2-it` (`192.168.23.100`)

### 3. Extended Access Control Lists (ACLs)
Implemented via Linux `iptables` mirroring Cisco IOS ACLs:
* **HQ**:
  * `BLOCK_HR_TO_FINANCE`: Blocks traffic from `192.168.1.0/24` to `192.168.2.0/24`.
  * `BLOCK_FINANCE_TO_HR`: Blocks traffic from `192.168.2.0/24` to `192.168.1.0/24`.
  * `BLOCK_FINANCE_TO_ADMIN`: Blocks traffic from `192.168.2.0/24` to `192.168.4.0/24`.
  * `BLOCK_ADMIN_TO_FINANCE`: Blocks traffic from `192.168.4.0/24` to `192.168.2.0/24` & `192.168.1.0/24`.
* **Branch 1**:
  * `BLOCK_HR_TO_FINANCE_BR1` & `BLOCK_FINANCE_TO_HR_BR1` (blocks inter-department communication between HR `192.168.11.0/24` and Finance `192.168.12.0/24`).
* **Branch 2**:
  * `BLOCK_HR_TO_FINANCE_BR2` & `BLOCK_FINANCE_TO_HR_BR2` (blocks inter-department communication between HR `192.168.21.0/24` and Finance `192.168.22.0/24`).

---

## Running the Lab

1. Prepare configuration and router images:
   ```sh
   ./prepare.sh
   ```

2. Start all services:
   ```sh
   docker compose up -d
   ```

3. Verify OSPF Convergence (15–25 seconds):
   ```sh
   docker exec lab-hq vtysh -c 'show ip ospf neighbor'
   docker exec lab-br1 vtysh -c 'show ip route ospf'
   ```

4. Test Inter-Branch Connectivity & Services:
   * **Ping across branches** (e.g. HQ HR to Branch 2 HR):
     ```sh
     docker exec lab-pc-hq-hr ping -c 3 192.168.21.100
     ```
   * **Access Corporate Web Portal from Branch 2**:
     ```sh
     docker exec lab-pc-br2-it wget -qO- http://192.168.5.20
     ```
   * **Verify ACL Blocking** (e.g. HR blocked from Finance):
     ```sh
     docker exec lab-pc-hq-hr ping -c 2 192.168.2.100  # Will drop with 100% loss
     ```

5. Stop Capture & Clean up:
   ```sh
   docker compose stop capture
   docker compose down
   ```
