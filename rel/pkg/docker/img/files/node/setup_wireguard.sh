#!/bin/bash
# -------------------------------------------------------------------
#
# Copyright (c) 2026 Workday, Inc.
#
# This file is provided to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file
# except in compliance with the License.  You may obtain
# a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# -------------------------------------------------------------------
#
# Set up WireGuard interface inside a Riak container.
# Runs BEFORE Riak starts.  No-op when ENABLE_WIREGUARD != "true".
#
# Expects:
#   - /etc/wireguard/wg0.conf  (mounted from host via docker-compose volume)
#   - Environment variables: ENABLE_WIREGUARD, WG_IP, ERL_EPMD_ADDRESS
#
# Configures:
#   - wg0 interface with tunnel IP
#   - Erlang inet_dist_use_interface in advanced.config (so distribution
#     only listens on wg0, critical for single-NIC production hosts)

set -euo pipefail

if [ "${ENABLE_WIREGUARD:-false}" != "true" ]; then
    exit 0
fi

echo "=== WireGuard Setup ==="

# --- validate inputs --------------------------------------------------

if [ -z "${WG_IP:-}" ]; then
    echo "ERROR: WG_IP environment variable is required" >&2
    exit 1
fi

WG_CONF="/etc/wireguard/wg0.conf"
if [ ! -f "$WG_CONF" ]; then
    echo "ERROR: WireGuard config not found at $WG_CONF" >&2
    echo "Did you run wireguard/generate_keys.sh on the host?" >&2
    exit 1
fi

# --- bring up WireGuard -----------------------------------------------

echo "Bringing up wg0 interface (${WG_IP})..."

# wg-quick requires a writable copy (the mount may be :ro)
cp "$WG_CONF" /tmp/wg0.conf
chmod 600 /tmp/wg0.conf

# Kernel WireGuard creates interfaces via netlink. It needs NET_ADMIN,
# not /dev/net/tun.  This works on Docker Desktop for Mac (LinuxKit VM kernel
# 5.15+ has WireGuard built in) without any device mappings.
#
# If the kernel path fails, we fall back to wireguard-go which DOES need
# /dev/net/tun, so we create it if missing.
if ! wg-quick up /tmp/wg0.conf; then
    echo "Kernel WireGuard failed, attempting wireguard-go userspace fallback..."
    if command -v wireguard-go &>/dev/null; then
        if [ ! -e /dev/net/tun ]; then
            echo "Creating /dev/net/tun device..."
            mkdir -p /dev/net
            mknod /dev/net/tun c 10 200
            chmod 666 /dev/net/tun
        fi
        wireguard-go wg0
        WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go wg-quick up /tmp/wg0.conf
    else
        echo "ERROR: Neither kernel WireGuard nor wireguard-go available." >&2
        echo "Install wireguard-go for userspace WireGuard support." >&2
        exit 1
    fi
fi

# --- verify interface -------------------------------------------------

echo "Verifying wg0 interface..."
ip addr show wg0
echo ""
wg show wg0
echo ""

# --- wait for at least one peer to be reachable -----------------------

echo "Checking peer connectivity..."
PEER_IPS=$(grep -E "^AllowedIPs" "$WG_CONF" | awk '{print $3}' | cut -d/ -f1)

reachable=0
for attempt in $(seq 1 30); do
    for pip in $PEER_IPS; do
        if ping -c 1 -W 1 "$pip" &>/dev/null; then
            reachable=$((reachable + 1))
        fi
    done
    if [ $reachable -gt 0 ]; then
        echo "WireGuard mesh: $reachable peer(s) reachable"
        break
    fi
    echo "No peers reachable yet (attempt $attempt/30), waiting..."
    sleep 2
done

if [ $reachable -eq 0 ]; then
    echo "WARNING: No WireGuard peers reachable after 60s. Proceeding anyway."
    echo "WireGuard will establish connections as peers come online."
fi

# --- configure Erlang distribution for WireGuard interface ------------
# On single-NIC production hosts, this prevents EPMD and Erlang dist
# from being accessible on the physical interface (bypassing WireGuard).

WG_IP_TUPLE=$(echo "$WG_IP" | awk -F. '{printf "{%s,%s,%s,%s}", $1, $2, $3, $4}')
ADVANCED_CONFIG="/root/riak_node/etc/advanced.config"

ESCRIPT=$(ls /root/riak_node/erts-*/bin/escript 2>/dev/null | head -1)
if [ -z "$ESCRIPT" ]; then
    echo "ERROR: escript not found in Riak release at /root/riak_node/erts-*/bin/" >&2
    exit 1
fi

echo "Merging inet_dist_use_interface into advanced.config..."
"$ESCRIPT" /root/merge_advanced_config.escript \
    "$ADVANCED_CONFIG" \
    kernel \
    inet_dist_use_interface \
    "$WG_IP_TUPLE"

echo "ERL_EPMD_ADDRESS = ${ERL_EPMD_ADDRESS:-not set}"
echo "=== WireGuard Setup Complete ==="
