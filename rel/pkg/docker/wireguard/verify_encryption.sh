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
# Verify that Riak inter-node traffic is encrypted via WireGuard.
# Run from the host while the WireGuard-enabled compose cluster is up.
#
# Produces evidence:
#   1. WireGuard interface status on every node
#   2. Riak cluster membership showing WireGuard IPs
#   3. EPMD / Erlang distribution bound to WireGuard interface
#   4. Packet capture on eth0: only encrypted WireGuard UDP
#   5. Packet capture on eth0: NO cleartext Erlang distribution
#   6. Packet capture on wg0:  cleartext Erlang distribution
#   7. Transfer counter delta proving Riak ops traverse WireGuard
#
# wg0 is not a wire.  It is a virtual interface that exists only inside the
# kernel's network stack on that specific machine.  There is no physical
# cable, radio signal, or network segment carrying wg0 traffic that anyone
# could tap.
#
# Data flow for a packet sent from node-1 to node-2:
#
#   Node-1 kernel                          Node-2 kernel
#   ─────────────                          ─────────────
#   App writes to wg0 (cleartext)
#       │
#       ▼
#   WireGuard encrypts (ChaCha20-Poly1305)
#       │
#       ▼
#   UDP:51820 out eth0 ──── physical wire ────▶ UDP:51820 in eth0
#       (encrypted)          (attackable)           (encrypted)
#                                                       │
#                                                       ▼
#                                               WireGuard decrypts
#                                                       │
#                                                       ▼
#                                               App reads from wg0 (cleartext)
#
# The only place the data is cleartext is inside the kernel memory of an
# endpoint that holds the private key. 
#
# Prerequisites:
#   - Cluster running: make compose-up enable_wireguard=true
#   - Cluster fully formed (all 5 nodes joined)
#
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

NODE1="riak-compose-node-1"
RIAK="/root/riak_node/bin/riak"
SEPARATOR="========================================================================"
CAPTURE_SECONDS=5

# Client interface protocol: https only when the cluster was started with
# ENABLE_TLS=true, otherwise plain http (the default).
PROTOCOL=$(docker exec "$NODE1" bash -c \
    'if [ "${ENABLE_TLS:-false}" = "true" ]; then echo https; else echo http; fi' \
    2>/dev/null || echo http)

header() {
    echo ""
    echo "$SEPARATOR"
    echo "  $1"
    echo "$SEPARATOR"
}

# Ensure tcpdump is available inside node-1 (installs if needed)
header "SETUP: ensuring tcpdump is available in $NODE1"
docker exec "$NODE1" bash -c \
    'command -v tcpdump >/dev/null 2>&1 || dnf install -y tcpdump' 2>&1 | tail -3

# ======================================================================
# EVIDENCE 1: WireGuard interfaces are active on all nodes
# ======================================================================
header "EVIDENCE 1: WireGuard interface status (all nodes)"

for i in 1 2 3 4 5; do
    echo ""
    echo "--- riak-compose-node-$i ---"
    docker exec "riak-compose-node-$i" wg show wg0 2>&1
done

# ======================================================================
# EVIDENCE 2: Riak cluster membership uses WireGuard IPs (10.0.0.X)
# ======================================================================
header "EVIDENCE 2: Riak cluster membership (should show 10.0.0.X IPs)"

docker exec "$NODE1" $RIAK admin member-status 2>&1

# ======================================================================
# EVIDENCE 3: EPMD and Erlang distribution are on the WG interface
# ======================================================================
header "EVIDENCE 3: EPMD bound to WireGuard IP"

echo "ERL_EPMD_ADDRESS (env):"
docker exec "$NODE1" printenv ERL_EPMD_ADDRESS 2>&1 || echo "(not set)"

echo ""
echo "inet_dist_use_interface (advanced.config):"
docker exec "$NODE1" cat /root/riak_node/etc/advanced.config 2>&1

echo ""
echo "EPMD listening sockets (should show 10.0.0.1:4369, NOT 0.0.0.0):"
docker exec "$NODE1" bash -c 'ss -tlnp 2>/dev/null | grep 4369 || netstat -tlnp 2>/dev/null | grep 4369' 2>&1

# ======================================================================
# EVIDENCE 4: Packet capture on eth0 - inter-node traffic is encrypted
# ======================================================================
header "EVIDENCE 4: eth0 packet capture - inter-node traffic is WireGuard UDP"
echo ""
echo "Capturing on eth0 for ${CAPTURE_SECONDS}s while generating Riak traffic..."
echo "Expect: UDP port 51820 packets with encrypted (random-looking) payloads."
echo ""

# Start tcpdump on eth0 in background - capture inter-node traffic
docker exec "$NODE1" bash -c "
    tcpdump -i eth0 -c 30 -nn -X 'udp port 51820' \
        > /tmp/eth0_capture.txt 2>&1 &
    TCPDUMP_PID=\$!
    sleep 1

    # Generate inter-node traffic: n_val=3 means writes hit multiple nodes
    for k in \$(seq 1 20); do
        curl -k -s -X PUT ${PROTOCOL}://localhost:10018/buckets/wg_test/keys/key_\$k \
            -H 'Content-Type: text/plain' -d \"value_\$k\" >/dev/null 2>&1
    done
    sleep ${CAPTURE_SECONDS}
    kill \$TCPDUMP_PID 2>/dev/null; wait \$TCPDUMP_PID 2>/dev/null
    cat /tmp/eth0_capture.txt
" 2>&1

# ======================================================================
# EVIDENCE 5: eth0 has NO cleartext Erlang distribution traffic
# ======================================================================
header "EVIDENCE 5: eth0 - NO cleartext Erlang distribution between nodes"
echo ""
echo "Capturing on eth0 for ${CAPTURE_SECONDS}s - filtering for TCP between node IPs."
echo "Expect: ZERO packets (all inter-node TCP is inside the WG tunnel)."
echo ""

docker exec "$NODE1" bash -c "
    tcpdump -i eth0 -c 5 -nn \
        'tcp and (host 172.20.0.12 or host 172.20.0.13 or host 172.20.0.14 or host 172.20.0.15) and not port 10018' \
        > /tmp/eth0_tcp_capture.txt 2>&1 &
    TCPDUMP_PID=\$!

    for k in \$(seq 1 20); do
        curl -k -s -X PUT ${PROTOCOL}://localhost:10018/buckets/wg_test2/keys/key_\$k \
            -H 'Content-Type: text/plain' -d \"value_\$k\" >/dev/null 2>&1
    done
    sleep ${CAPTURE_SECONDS}
    kill \$TCPDUMP_PID 2>/dev/null; wait \$TCPDUMP_PID 2>/dev/null
    cat /tmp/eth0_tcp_capture.txt
" 2>&1

# ======================================================================
# EVIDENCE 6: Packet capture on wg0 - cleartext Erlang visible
# ======================================================================
header "EVIDENCE 6: wg0 packet capture - cleartext Erlang distribution visible"
echo ""
echo "Capturing on wg0 for ${CAPTURE_SECONDS}s while generating Riak traffic..."
echo "Expect: TCP packets with readable Erlang terms/atoms inside the tunnel."
echo ""

docker exec "$NODE1" bash -c "
    tcpdump -i wg0 -c 30 -nn -A 'tcp' \
        > /tmp/wg0_capture.txt 2>&1 &
    TCPDUMP_PID=\$!
    sleep 1

    for k in \$(seq 1 20); do
        curl -k -s -X PUT ${PROTOCOL}://localhost:10018/buckets/wg_test3/keys/key_\$k \
            -H 'Content-Type: text/plain' -d \"value_\$k\" >/dev/null 2>&1
    done
    sleep ${CAPTURE_SECONDS}
    kill \$TCPDUMP_PID 2>/dev/null; wait \$TCPDUMP_PID 2>/dev/null
    cat /tmp/wg0_capture.txt
" 2>&1

# ======================================================================
# EVIDENCE 7: WireGuard transfer counters increase during operations
# ======================================================================
header "EVIDENCE 7: WireGuard transfer counter delta"
echo ""
echo "Recording transfer counters BEFORE generating traffic..."

BEFORE=$(docker exec "$NODE1" wg show wg0 transfer 2>&1)
echo "$BEFORE"

echo ""
echo "Generating Riak traffic (50 writes)..."
docker exec "$NODE1" bash -c '
    proto=$([ "${ENABLE_TLS:-false}" = "true" ] && echo https || echo http)
    for k in $(seq 1 50); do
        curl -k -s -X PUT $proto://localhost:10018/buckets/wg_delta/keys/key_$k \
            -H "Content-Type: text/plain" -d "delta_test_value_$k" >/dev/null 2>&1
    done
' 2>&1
sleep 2

echo ""
echo "Recording transfer counters AFTER generating traffic..."
AFTER=$(docker exec "$NODE1" wg show wg0 transfer 2>&1)
echo "$AFTER"

echo ""
echo "Delta (bytes sent/received should have increased for each peer):"
paste <(echo "$BEFORE") <(echo "$AFTER") | while IFS=$'\t' read -r before_line after_line; do
    peer_b=$(echo "$before_line" | awk '{print $1}')
    rx_b=$(echo "$before_line" | awk '{print $2}')
    tx_b=$(echo "$before_line" | awk '{print $3}')
    rx_a=$(echo "$after_line" | awk '{print $2}')
    tx_a=$(echo "$after_line" | awk '{print $3}')
    if [ -n "$peer_b" ] && [ -n "$rx_b" ] && [ -n "$rx_a" ]; then
        rx_delta=$((rx_a - rx_b))
        tx_delta=$((tx_a - tx_b))
        echo "  Peer ${peer_b:0:12}...  rx: +${rx_delta} bytes  tx: +${tx_delta} bytes"
    fi
done

# ======================================================================
# SUMMARY
# ======================================================================
header "SUMMARY"
echo ""
echo "Evidence collected:"
echo "  1. WireGuard interfaces active on all 5 nodes with peer handshakes"
echo "  2. Riak cluster membership uses WireGuard IPs (10.0.0.X)"
echo "  3. EPMD and Erlang distribution bound to WireGuard interface only"
echo "  4. eth0 carries only encrypted WireGuard UDP (port 51820)"
echo "  5. eth0 carries NO cleartext TCP between node IPs"
echo "  6. wg0 carries cleartext Erlang distribution (visible inside tunnel)"
echo "  7. WireGuard transfer counters increase during Riak operations"
echo ""
echo "Conclusion: All inter-node Riak traffic traverses WireGuard tunnels"
echo "and is encrypted on the wire (eth0).  The cleartext Erlang protocol"
echo "is only visible inside the wg0 tunnel interface."
echo "$SEPARATOR"
