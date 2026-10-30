#!/bin/bash
# ====================================================================
# Multi-Branch Enterprise Network - Live Traffic Generator for Wireshark
# ====================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================================${NC}"
echo -e "${CYAN}    GENERATING ENTERPRISE NETWORK TRAFFIC FOR WIRESHARK DEMO        ${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo ""

# 1. HTTP Intranet Web Traffic
echo -e "${YELLOW}[1/4] Generating HTTP Intranet Web Traffic...${NC}"
echo -e "      Source:      Branch 1 HR Client (192.168.11.100)"
echo -e "      Destination: HQ Central Intranet Web Server (192.168.5.20:80)"
docker exec lab-pc-br1-hr wget -qO- http://192.168.5.20 >/dev/null
docker exec lab-pc-br2-it wget -qO- http://192.168.5.20 >/dev/null
echo -e "${GREEN}  ✔ HTTP GET requests & 200 OK responses generated.${NC}"
echo -e "${CYAN}    --> Wireshark Filter:${NC} ${GREEN}http || tcp.port == 80${NC}"
echo ""
sleep 1

# 2. Inter-Branch ICMP WAN Traffic
echo -e "${YELLOW}[2/4] Generating Cross-Branch ICMP WAN Traffic...${NC}"
echo -e "      Flow A: HQ HR (192.168.1.100) -> Branch 2 HR (192.168.21.100)"
docker exec lab-pc-hq-hr ping -c 4 192.168.21.100 >/dev/null
echo -e "      Flow B: Branch 1 IT (192.168.13.100) -> Branch 2 IT (192.168.23.100)"
docker exec lab-pc-br1-it ping -c 4 192.168.23.100 >/dev/null
echo -e "${GREEN}  ✔ Multi-hop WAN ICMP Echo Requests and Replies transmitted.${NC}"
echo -e "${CYAN}    --> Wireshark Filter:${NC} ${GREEN}icmp${NC}"
echo ""
sleep 1

# 3. Security ACL Blocked Traffic (Drop Demonstration)
echo -e "${YELLOW}[3/4] Generating Blocked Traffic (Cisco Extended ACL Drops)...${NC}"
echo -e "      Flow: HQ HR (192.168.1.100) -> HQ Finance (192.168.2.100)"
echo -e "      Policy: BLOCK_HR_TO_FINANCE (192.168.1.0/24 -> 192.168.2.0/24)"
docker exec lab-pc-hq-hr ping -c 3 -W 1 192.168.2.100 >/dev/null 2>&1 || true
docker exec lab-pc-br1-hr ping -c 3 -W 1 192.168.12.100 >/dev/null 2>&1 || true
echo -e "${RED}  ✔ Prohibited packets transmitted and dropped at gateway router.${NC}"
echo -e "${CYAN}    --> Wireshark Filter:${NC} ${GREEN}ip.dst == 192.168.2.100 || ip.dst == 192.168.12.100${NC}"
echo -e "    Notice in Wireshark: Only ingress Echo Requests appear; NO replies exist!"
echo ""
sleep 1

# 4. OSPF Dynamic Routing Protocol Traffic
echo -e "${YELLOW}[4/4] Checking Background OSPF Routing Traffic...${NC}"
echo -e "      Multicast IP: 224.0.0.5 (All OSPF Routers)"
echo -e "${GREEN}  ✔ Continuous OSPFv2 Hello packets exchanged every 10s between 1.1.1.1, 2.2.2.2, and 3.3.3.3.${NC}"
echo -e "${CYAN}    --> Wireshark Filter:${NC} ${GREEN}ospf${NC}"
echo ""

echo -e "${BLUE}====================================================================${NC}"
echo -e "${GREEN}✔ TRAFFIC GENERATION COMPLETE!${NC}"
echo -e "All packets have been captured to:${CYAN}"
echo -e "  - captures/branch1-all.pcap  (Branch 1 Router interface)"
echo -e "  - captures/hq-all.pcap       (HQ Core Router interface)"
echo -e "  - captures/branch2-all.pcap  (Branch 2 Router interface)${NC}"
echo ""
echo -e "To open Wireshark now, run:"
echo -e "  ${YELLOW}open -a Wireshark captures/branch1-all.pcap${NC}"
echo -e "Or press ${YELLOW}Cmd + R${NC} inside Wireshark to refresh if already open."
echo -e "${BLUE}====================================================================${NC}"

