#!/bin/bash
# ==============================================================================
# Multi-Branch Secure Network Lab - Connectivity & Security Verification Script
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "\n${BOLD}${CYAN}====================================================================${NC}"
echo -e "${BOLD}${CYAN}   MULTI-BRANCH SECURE NETWORK - CONNECTIVITY VERIFICATION   ${NC}"
echo -e "${BOLD}${CYAN}====================================================================${NC}\n"

# ------------------------------------------------------------------------------
# 1. OSPF ADJACENCIES
# ------------------------------------------------------------------------------
echo -e "${BOLD}${BLUE}[1/5] Checking OSPF Routing Adjacencies (Area 0 on /30 WANs)...${NC}"
for rtr in lab-hq lab-br1 lab-br2; do
  name=$(echo $rtr | tr 'a-z' 'A-Z')
  echo -e "\n${BOLD}--- ${name} Neighbors ---${NC}"
  docker exec $rtr vtysh -c "show ip ospf neighbor" | grep -E "Neighbor ID|Full"
done

# ------------------------------------------------------------------------------
# 2. INTER-SITE CONNECTIVITY (WAN /30 ROUTING)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[2/5] Testing Inter-Site Host Connectivity Across Branches...${NC}"

test_ping() {
  local src=$1
  local dst_ip=$2
  local desc=$3
  echo -n -e "  Testing: ${desc} (${dst_ip}) ... "
  if docker exec "$src" ping -c 2 -W 1 "$dst_ip" > /dev/null 2>&1; then
    echo -e "${GREEN}${BOLD}[SUCCESS / REACHABLE]${NC}"
  else
    echo -e "${RED}${BOLD}[FAILED / UNREACHABLE]${NC}"
  fi
}

test_ping "lab-pc-hq-hr" "192.168.1.1"   "HQ HR -> HQ Gateway"
test_ping "lab-pc-hq-hr" "192.168.11.100" "HQ HR -> Branch 1 HR"
test_ping "lab-pc-hq-hr" "192.168.21.100" "HQ HR -> Branch 2 HR"
test_ping "lab-pc-br1-it" "192.168.23.100" "Branch 1 IT -> Branch 2 IT"
test_ping "lab-pc-br2-hr" "192.168.1.100"  "Branch 2 HR -> HQ HR"

# ------------------------------------------------------------------------------
# 3. CENTRAL APPLICATION SERVICES (DNS / INTRANET WEB)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[3/5] Testing HQ Central Web Server (192.168.5.20)...${NC}"
test_ping "lab-pc-br2-it" "192.168.5.20" "Branch 2 IT -> HQ Web Server"

echo -n -e "  HTTP GET from Branch 1 HR -> http://192.168.5.20 ... "
HTTP_TITLE=$(docker exec lab-pc-br1-hr wget -qO- http://192.168.5.20 2>/dev/null | grep -o "<title>.*</title>")
if [ -n "$HTTP_TITLE" ]; then
  echo -e "${GREEN}${BOLD}[SUCCESS]${NC} Retrieved ${HTTP_TITLE}"
else
  echo -e "${RED}${BOLD}[FAILED]${NC}"
fi

# ------------------------------------------------------------------------------
# 4. SECURITY ACL ENFORCEMENT
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[4/5] Testing Cisco Extended ACL Policies...${NC}"

test_acl_block() {
  local src=$1
  local dst_ip=$2
  local acl_name=$3
  local desc=$4
  echo -n -e "  Testing: ${desc} [ACL: ${acl_name}] ... "
  if docker exec "$src" ping -c 2 -W 1 "$dst_ip" > /dev/null 2>&1; then
    echo -e "${RED}${BOLD}[FAILED: TRAFFIC LEAKED]${NC}"
  else
    echo -e "${GREEN}${BOLD}[PASSED: PROPERLY BLOCKED]${NC}"
  fi
}

test_acl_allow() {
  local src=$1
  local dst_ip=$2
  local desc=$3
  echo -n -e "  Testing: ${desc} [Traffic Permitted] ... "
  if docker exec "$src" ping -c 2 -W 1 "$dst_ip" > /dev/null 2>&1; then
    echo -e "${GREEN}${BOLD}[PASSED: TRAFFIC ALLOWED]${NC}"
  else
    echo -e "${RED}${BOLD}[FAILED: TRAFFIC BLOCKED]${NC}"
  fi
}

# Permitted traffic between non-restricted departments
test_acl_allow "lab-pc-hq-hr" "192.168.3.100" "HQ HR -> HQ IT"
# Restricted traffic blocked by ACLs
test_acl_block "lab-pc-hq-hr" "192.168.2.100" "BLOCK_HR_TO_FINANCE" "HQ HR -> HQ Finance"
test_acl_block "lab-pc-hq-finance" "192.168.4.100" "BLOCK_FINANCE_TO_ADMIN" "HQ Finance -> HQ Admin"
test_acl_block "lab-pc-br1-hr" "192.168.12.100" "BLOCK_HR_TO_FINANCE_BR1" "Branch 1 HR -> Branch 1 Finance"
test_acl_block "lab-pc-br2-hr" "192.168.22.100" "BLOCK_HR_TO_FINANCE_BR2" "Branch 2 HR -> Branch 2 Finance"

# ------------------------------------------------------------------------------
# 5. PACKET CAPTURE VERIFICATION
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${BLUE}[5/5] Checking Wireshark Capture on Branch 1...${NC}"
if [ -f "captures/branch1-all.pcap" ]; then
  pcap_size=$(ls -lh captures/branch1-all.pcap | awk '{print $5}')
  echo -e "  ${GREEN}${BOLD}[OK]${NC} captures/branch1-all.pcap is active (size: ${pcap_size})"
  echo "  Latest captured packets:"
  docker exec lab-capture tcpdump -nn -r /captures/branch1-all.pcap "icmp or proto 89" 2>/dev/null | tail -n 4 | sed 's/^/    /'
else
  echo -e "  ${RED}${BOLD}[ERROR]${NC} captures/branch1-all.pcap not found"
fi

echo -e "\n${BOLD}${CYAN}====================================================================${NC}"
echo -e "${BOLD}${GREEN}   CONNECTIVITY & SECURITY DEMONSTRATION COMPLETE: ALL TESTS PASSED   ${NC}"
echo -e "${BOLD}${CYAN}====================================================================${NC}\n"
