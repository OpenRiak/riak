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

# Script for starting a joining node in a Riak cluster
# Usage: start_joining_node.sh <node_ip> <primary_node_ip> [health_check_ip]
#
#   node_ip          - IP for this node's Riak nodename (Docker IP or WireGuard IP)
#   primary_node_ip  - IP of the primary node for cluster join
#   health_check_ip  - (optional) IP to use for HTTP health check of the primary
#                      node.  Defaults to primary_node_ip.  When using WireGuard,
#                      pass the Docker bridge IP here so the health check doesn't
#                      depend on the primary's WireGuard tunnel being up first.

set -e

NODE_IP="$1"
PRIMARY_IP="$2"
HEALTH_CHECK_IP="${3:-$PRIMARY_IP}"

if [ -z "$NODE_IP" ] || [ -z "$PRIMARY_IP" ]; then
    echo "Error: Both node IP and primary node IP are required"
    echo "Usage: $0 <node_ip> <primary_node_ip> [health_check_ip]"
    exit 1
fi

echo "Starting joining node $NODE_IP, connecting to primary $PRIMARY_IP"

# Select the TLS (https) or plain (http) riak.conf based on ENABLE_TLS.
# Default is plain HTTP; restore the plain variant otherwise so toggling
# across restarts is idempotent.  This must happen before the sed below.
NODE_ETC="/root/riak_node/etc"
if [ "${ENABLE_TLS:-false}" = "true" ] && [ -f "${NODE_ETC}/riak.conf.tls" ]; then
    cp "${NODE_ETC}/riak.conf.tls" "${NODE_ETC}/riak.conf"
elif [ -f "${NODE_ETC}/riak.conf.notls" ]; then
    cp "${NODE_ETC}/riak.conf.notls" "${NODE_ETC}/riak.conf"
fi

# Configure nodename and bind listeners to all interfaces (required for
# multi-container operation where nodes and clients connect via eth0/wg0).
# The devrel default is 127.0.0.1
sed -i \
    -e "s/nodename = dev1@127.0.0.1/nodename = riak@$NODE_IP/" \
    -e "s/listener.https.internal = 127.0.0.1/listener.https.internal = 0.0.0.0/" \
    -e "s/listener.http.internal = 127.0.0.1/listener.http.internal = 0.0.0.0/" \
    -e "s/listener.protobuf.internal = 127.0.0.1/listener.protobuf.internal = 0.0.0.0/" \
    /root/riak_node/etc/riak.conf

# ensure handoff.ip is set to 0.0.0.0 to allow inter-node handoff just in case.
echo "handoff.ip = 0.0.0.0" >> /root/riak_node/etc/riak.conf

# Wait for node 1 to be available
echo 'Waiting for node 1 to be ready...'
sleep 10

# Health-check protocol matches the active listener (https only with TLS).
if [ "${ENABLE_TLS:-false}" = "true" ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi
while ! curl -k -s --connect-timeout 2 $PROTOCOL://$HEALTH_CHECK_IP:10018/ping >/dev/null 2>&1; do
  echo 'Node 1 not ready yet, waiting...'
  sleep 2
done
echo 'Node 1 is ready!'

# Start this node
/root/riak_node/bin/riak daemon

# Wait for this node to be up
while ! /root/riak_node/bin/riak ping; do sleep 1; done

# Join the cluster with retry logic
join_attempts=0
max_attempts=10
while [ $join_attempts -lt $max_attempts ]; do
  echo "Join attempt $((join_attempts + 1)) of $max_attempts..."
  join_output=$(/root/riak_node/bin/riak admin cluster join riak@$PRIMARY_IP 2>&1)
  echo "Join output: $join_output"
  if echo "$join_output" | grep -q "Success"; then
    echo 'Successfully joined cluster!'
    break
  else
    join_attempts=$((join_attempts + 1))
    if [ $join_attempts -lt $max_attempts ]; then
      echo 'Join failed. Retrying in 5 seconds...'
      sleep 5
    else
      echo 'Failed to join cluster after '$max_attempts' attempts'
      exit 1
    fi
  fi
done

echo "Node $NODE_IP successfully joined the cluster"
