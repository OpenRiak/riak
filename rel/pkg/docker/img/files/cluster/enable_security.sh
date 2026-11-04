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

# Enable security if ENABLE_SECURITY is set to true (default: false)
if [ "${ENABLE_SECURITY:-false}" != "true" ]; then
    echo "Security is disabled"
    exit 0
fi

# Riak security requires TLS.
if [ "${ENABLE_TLS:-false}" != "true" ]; then
    echo "ERROR: ENABLE_SECURITY=true requires ENABLE_TLS=true." >&2
    exit 1
fi

echo "Enabling security"

echo "Waiting for ring to be ready..."
while true; do
    if riak admin ring-status | grep -q "Ring Ready: true"; then
        echo "Ring is ready!"
        break
    fi
    echo "Ring not ready yet, waiting..."
    sleep 5
done

riak admin security enable
sleep 1
riak admin security add-group immutable
sleep 1
riak admin security add-group mutable
sleep 1
riak admin security grant riak_kv.put on any to mutable
sleep 1
riak admin security grant riak_kv.delete on any to mutable
sleep 1
riak admin security grant riak_kv.get on any to immutable
sleep 1
riak admin security add-user riakadmin groups=mutable,immutable password=123456
sleep 1
riak admin security add-user readonly groups=immutable password=123456
sleep 1
riak admin security add-user riakwriteclient groups=mutable,immutable
sleep 1
riak admin security add-user riakreadclient groups=immutable
sleep 1
riak admin security add-source riakadmin 0.0.0.0/0 password
sleep 1
riak admin security add-source readonly 0.0.0.0/0 password
sleep 1
riak admin security add-source riakwriteclient 0.0.0.0/0 certificate
sleep 1
riak admin security add-source riakreadclient 0.0.0.0/0 certificate
sleep 1
riak admin security add-source all 0.0.0.0/0 certificate
sleep 1
curl -X PUT -k -u"riakadmin:123456" https://localhost:10018/buckets/first/keys/firstkey -H "Content-Type: text/plain" -d 'added value: success'
sleep 1
curl -X GET -k -u"riakadmin:123456" https://localhost:10018/buckets/first/keys/firstkey
echo
