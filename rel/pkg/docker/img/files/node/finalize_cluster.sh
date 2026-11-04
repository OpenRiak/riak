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

# Script for finalizing a Riak cluster (committing the cluster plan)
# Usage: finalize_cluster.sh <total_node_count>

set -e

TOTAL_NODES="$1"

if [ -z "$TOTAL_NODES" ]; then
    echo "Error: Total node count is required"
    echo "Usage: $0 <total_node_count>"
    exit 1
fi

echo "Finalizing cluster with $TOTAL_NODES nodes"

# Wait for all nodes to join before committing cluster plan
echo "Waiting for all $TOTAL_NODES nodes to join the cluster..."
while true; do
  node_count=$(/root/riak_node/bin/riak admin cluster status | grep -c 'riak@')
  echo "Found $node_count nodes in cluster membership"
  if [ $node_count -eq $TOTAL_NODES ]; then
    echo "All $TOTAL_NODES nodes have joined the cluster!"
    break
  else
    echo 'Still waiting for all nodes to join. Current membership:'
    /root/riak_node/bin/riak admin cluster status
    sleep 5
  fi
done

# Commit the cluster plan (final node does this)
echo 'All nodes joined. Planning and committing cluster...'
/root/riak_node/bin/riak admin cluster plan
/root/riak_node/bin/riak admin cluster commit

# Show cluster status for verification
echo 'Cluster formation complete!'
/root/riak_node/bin/riak admin cluster status
