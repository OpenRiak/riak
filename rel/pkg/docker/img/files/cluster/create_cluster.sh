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

echo Creating Riak 5 Node Cluster
echo Verifying nodes are up
for i in {1..5}; do
    attempt=0
    while ! /root/rt/riak/openriak/dev/dev"${i}"/riak/bin/riak ping; do
        attempt=$((attempt + 1))
        if [ $attempt -ge 10 ]; then
            echo "Node dev${i} failed to start after 10 attempts"
            exit 1
        fi
        sleep 1
    done
done
echo Joining nodes into a cluster
for i in {2..5}; do
    attempt=0
    while /root/rt/riak/openriak/dev/dev"${i}"/riak/bin/riak admin cluster join dev1@127.0.0.1 | grep "Join failed"; do
        attempt=$((attempt + 1))
        if [ $attempt -ge 10 ]; then
            echo "Node dev${i} failed to join cluster after 10 attempts"
            exit 1
        fi
        sleep 5
    done
done
/root/rt/riak/openriak/dev/dev1/riak/bin/riak admin cluster plan
/root/rt/riak/openriak/dev/dev1/riak/bin/riak admin cluster commit
/root/rt/riak/openriak/dev/dev1/riak/bin/riak admin cluster status

ln -fs /root/rt/riak/openriak/dev/dev1/riak/bin/riak /usr/local/bin/riak
