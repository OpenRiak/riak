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

# Script for starting the primary (seed) node in a Riak cluster
# Usage: start_primary_node.sh <node_ip>

set -e

NODE_IP="$1"

if [ -z "$NODE_IP" ]; then
    echo "Error: Node IP address is required"
    echo "Usage: $0 <node_ip>"
    exit 1
fi

echo "Starting primary node with IP: $NODE_IP"

# Wait a moment for network to be ready
sleep 2

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

# Start the initialization
/usr/bin/bash /root/initialize_container.sh
