#!/bin/sh
set -e

# Wait for interfaces to settle
sleep 1
touch /etc/frr/vtysh.conf 2>/dev/null || true

# Identify WAN interfaces and configure exact Cisco /30 subnets
IF_WAN1=$(ip -o -4 addr show to 172.20.20.0/24 | awk '{print $2}')
IF_WAN2=$(ip -o -4 addr show to 172.20.30.0/24 | awk '{print $2}')

if [ -n "$IF_WAN1" ]; then
  ip addr flush dev "$IF_WAN1"
  ip addr add 10.10.10.6/30 brd 10.10.10.7 dev "$IF_WAN1"
  ip link set dev "$IF_WAN1" up
fi

if [ -n "$IF_WAN2" ]; then
  ip addr flush dev "$IF_WAN2"
  ip addr add 10.10.10.10/30 brd 10.10.10.11 dev "$IF_WAN2"
  ip link set dev "$IF_WAN2" up
fi

# Cisco IOS ACLs replication via iptables
# Extended ACL: BLOCK_HR_TO_FINANCE_BR2
iptables -A FORWARD -s 192.168.21.0/24 -d 192.168.22.0/24 -j DROP

# Extended ACL: BLOCK_FINANCE_TO_HR_BR2
iptables -A FORWARD -s 192.168.22.0/24 -d 192.168.21.0/24 -j DROP

# Execute standard FRR entrypoint
exec /usr/lib/frr/docker-start
