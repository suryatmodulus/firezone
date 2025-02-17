#!/usr/bin/env bash

# The integration tests call this to test Linux DNS control, using the `/etc/resolv.conf`
# method which only works well inside Alpine Docker containers.

set -euo pipefail

HTTPBIN=dns.httpbin

function client() {
    docker compose exec -it client "$@"
}

function client_nslookup() {
    # Skip the first 3 lines so that grep won't see the DNS server IP
    # `tee` here copies stdout to stderr
    client timeout 30 sh -c "nslookup $1 | tee >(cat 1>&2) | tail -n +4"
}

function gateway() {
    docker compose exec -it gateway "$@"
}

# Re-up the gateway since a local dev setup may run this back-to-back
docker compose up -d gateway

echo "# check original resolv.conf"
client sh -c "cat /etc/resolv.conf.firezone-backup"

echo "# Make sure gateway can reach httpbin by DNS"
gateway sh -c "curl --fail $HTTPBIN/get"

echo "# Try to ping httpbin as a DNS resource"
client sh -c "ping -W 1 -c 30 $HTTPBIN"

echo "# Access httpbin by DNS"
client sh -c "curl --fail $HTTPBIN/get"

echo "# Make sure it's going through the tunnel"
client_nslookup "$HTTPBIN" | grep "100\\.96\\.0\\."

echo "# Make sure a non-resource doesn't go through the tunnel"
client_nslookup "github.com" | grep -v "100\\.96.\\0\\."

echo "# Stop the gateway and make sure the resource is inaccessible"
docker compose stop gateway
client sh -c "curl --connect-timeout 15 --fail $HTTPBIN/get" && exit 1

exit 0
