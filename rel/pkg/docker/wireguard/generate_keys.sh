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
# Generate WireGuard key pairs and per-node wg0.conf files for a
# Riak multi-container cluster.  Run on the host BEFORE docker-compose up.
#
# Usage: generate_keys.sh [num_nodes]
#   num_nodes  - number of cluster nodes (default: 5)
#
# Output: run/wireguard/node-N/wg0.conf  (one per node)
#
# Requires: wireguard-tools (provides wg genkey / wg pubkey)
#   macOS:  brew install wireguard-tools
#   Linux:  dnf install wireguard-tools  (or apt install wireguard-tools)
#
#
#
################################################################
#
# WARNING: The following was written with AI assistance.
# It is not guaranteed to be correct or complete.
# I've read through it and I've run it but use at your own risk.
# Please review and test before using.
#
################################################################

set -euo pipefail

NUM_NODES="${1:-5}"
WG_DIR="run/wireguard"

# Docker bridge IPs must match docker-compose.yml (172.20.0.11 .. 172.20.0.1N)
DOCKER_BASE="172.20.0"
DOCKER_OFFSET=10          # node 1 = .11, node 2 = .12, ...

WG_SUBNET="10.0.0"        # WireGuard tunnel IPs: 10.0.0.1 .. 10.0.0.N
WG_PORT=51820

# --- sanity checks ---------------------------------------------------

if ! command -v wg &>/dev/null; then
    echo "ERROR: 'wg' not found. Install wireguard-tools first." >&2
    echo "  macOS:  brew install wireguard-tools" >&2
    echo "  Linux:  dnf install epel-release && dnf install wireguard-tools" >&2
    exit 1
fi

if [ "$NUM_NODES" -lt 2 ] || [ "$NUM_NODES" -gt 20 ]; then
    echo "ERROR: num_nodes must be between 2 and 20 (got $NUM_NODES)" >&2
    exit 1
fi

# --- generate keys ----------------------------------------------------

umask 077

rm -rf "$WG_DIR"
for i in $(seq 1 "$NUM_NODES"); do
    mkdir -p "$WG_DIR/node-$i"
    wg genkey > "$WG_DIR/node-$i/privatekey"
    wg pubkey < "$WG_DIR/node-$i/privatekey" > "$WG_DIR/node-$i/publickey"
done

# --- generate per-node wg0.conf files --------------------------------

for i in $(seq 1 "$NUM_NODES"); do
    PRIVATE_KEY=$(cat "$WG_DIR/node-$i/privatekey")

    cat > "$WG_DIR/node-$i/wg0.conf" <<EOF
[Interface]
Address = ${WG_SUBNET}.${i}/24
PrivateKey = ${PRIVATE_KEY}
ListenPort = ${WG_PORT}
MTU = 1420
EOF

    for j in $(seq 1 "$NUM_NODES"); do
        if [ "$i" -ne "$j" ]; then
            PEER_PUBLIC=$(cat "$WG_DIR/node-$j/publickey")
            DOCKER_IP="${DOCKER_BASE}.$((DOCKER_OFFSET + j))"

            cat >> "$WG_DIR/node-$i/wg0.conf" <<EOF

[Peer]
PublicKey = ${PEER_PUBLIC}
AllowedIPs = ${WG_SUBNET}.${j}/32
Endpoint = ${DOCKER_IP}:${WG_PORT}
PersistentKeepalive = 25
EOF
        fi
    done
done

echo "Generated WireGuard configs for ${NUM_NODES} nodes in ${WG_DIR}/"
for i in $(seq 1 "$NUM_NODES"); do
    echo "  node-$i: wg0 = ${WG_SUBNET}.${i}  endpoint = ${DOCKER_BASE}.$((DOCKER_OFFSET + i)):${WG_PORT}"
done
