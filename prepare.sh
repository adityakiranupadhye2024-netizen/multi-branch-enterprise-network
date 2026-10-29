#!/bin/sh
set -eu

IMG='quay.io/frrouting/frr:10.7.1'
mkdir -p configs/hq configs/br1 configs/br2 configs/dhcp configs/web captures

# Prepare FRR daemons config
docker run --rm "$IMG" cat /etc/frr/daemons > configs/daemons.original
sed 's/^ospfd=no/ospfd=yes/' configs/daemons.original > configs/daemons
if ! grep -q '^ospfd=yes' configs/daemons; then
  echo 'Could not enable ospfd automatically. Inspect configs/daemons.original and set ospfd=yes.'
  exit 1
fi
echo 'Prepared configs/daemons.'

# Make router setup scripts executable
chmod +x configs/hq/setup.sh configs/br1/setup.sh configs/br2/setup.sh

# Build custom router image with iptables
echo 'Building multi-branch-frr image...'
docker build -t multi-branch-frr:latest -f Dockerfile.router .

echo 'Lab environment prepared successfully.'
