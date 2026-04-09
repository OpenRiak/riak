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

# verify the container is initialized
while [ ! -f /root/initialized ]; do
    echo "Container not initialized yet. Please wait."
    sleep 5
done

# verify a user, bucket, key, and value are passed in
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <user> <bucket> <key>"
    exit 1
fi

# Use https only when TLS is enabled (ENABLE_TLS=true); default is plain HTTP.
if [ "${ENABLE_TLS:-false}" = "true" ]; then
    PROTO="https"
    CURL_TLS_OPT="-k"
else
    PROTO="http"
    CURL_TLS_OPT=""
fi

echo Calling the following:
echo curl -X DELETE ${CURL_TLS_OPT} -u"$1:XXXXXX" "${PROTO}://localhost:10018/buckets/$2/keys/$3"
curl -X DELETE ${CURL_TLS_OPT} -u"$1:123456" "${PROTO}://localhost:10018/buckets/$2/keys/$3"
echo