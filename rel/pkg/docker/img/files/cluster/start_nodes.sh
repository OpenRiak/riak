#!/usr/bin/bash
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

# default to starting 5 nodes if not specified
if [ -z "$1" ]; then
    end=5
else
    end=$1
fi

echo Starting $end Riak nodes
# always stop all nodes first
./stop_nodes.sh
# start only the nodes specified
for i in $(seq 1 $end); do
    echo "Starting dev${i}"
    etc="/root/rt/riak/openriak/dev/dev${i}/riak/etc"
    # Select the TLS (https) or plain (http) riak.conf based on ENABLE_TLS.
    # Default is plain HTTP; the .tls variant is only applied when opted in.
    # Restore the plain variant otherwise so toggling is idempotent.
    if [ "${ENABLE_TLS:-false}" = "true" ] && [ -f "${etc}/riak.conf.tls" ]; then
        cp "${etc}/riak.conf.tls" "${etc}/riak.conf"
    elif [ -f "${etc}/riak.conf.notls" ]; then
        cp "${etc}/riak.conf.notls" "${etc}/riak.conf"
    fi
    # configure listener on 0.0.0.0 only on node 1 (whichever protocol is active)
    if [ "$i" -eq 1 ]; then
        sed -i \
            -e "s/listener.https.internal = 127.0.0.1/listener.https.internal = 0.0.0.0/" \
            -e "s/listener.http.internal = 127.0.0.1/listener.http.internal = 0.0.0.0/" \
            -e "s/listener.protobuf.internal = 127.0.0.1/listener.protobuf.internal = 0.0.0.0/" \
            "${etc}/riak.conf"
    fi
    /root/rt/riak/openriak/dev/dev"${i}"/riak/bin/riak daemon # 1>/dev/null 2>&1
done
