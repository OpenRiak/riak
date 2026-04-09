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

# if ulimit is less than 65536, then set it to 65536
if [ "$(ulimit -n)" -lt 65536 ]; then
    ulimit -n 65536
fi

./start_nodes.sh

./create_cluster.sh

./enable_security.sh

# Publish TLS material to the shared volume only when TLS is enabled;
# the CA/client certs are only usable against the https listener.
if [ -d /var/run/riak ]; then
    rm -rf /var/run/riak/*
    if [ "${ENABLE_TLS:-false}" = "true" ]; then
        cp /root/rt/riak/openriak/dev/ca/riakca.ca.crt.pem /var/run/riak/
        cp /root/rt/riak/openriak/dev/client/riakwriteclient* /var/run/riak/
        cp /root/rt/riak/openriak/dev/client/riakreadclient* /var/run/riak/
    fi
fi
touch /root/initialized

while true; do
    if [ -f /root/shutdown ]; then
        rm /root/shutdown
        break
    fi
    sleep 5
done
