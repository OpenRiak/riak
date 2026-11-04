#!/usr/bin/env bash
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
# shellcheck disable=SC2164

# exit on error
set -e

# verify arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <container_type> <username> <group> [<openssl_config_file>]"
    echo "container_type: cluster, compose"
    echo "group: mutable, immutable"
    echo "openssl_config_file: optional"
    exit 1
fi

# verify container type
if [ "$1" != "cluster" ] && [ "$1" != "compose" ]; then
    echo "Invalid container type: $1"
    echo "container_type: cluster, compose"
    exit 1
fi

container_type="$1"
username="$2"
group="$3"

# set container name based on type
if [ "$container_type" = "compose" ]; then
    container_name="riak-compose-node-1"
else
    container_name="riak-#OS_TAG#-${container_type}-#TAG#"
fi

# verify the container is initialized
while ! docker exec -it "$container_name" test -f /root/initialized; do
    echo "Container not initialized yet. Please wait."
    sleep 5
done

# verify the group
if [ "$group" != "mutable" ] && [ "$group" != "immutable" ]; then
    echo "Invalid group: $group"
    echo "group: mutable, immutable"
    exit 1
fi

# if the group is mutable, then make it mutable,immutable
if [ "$group" = "mutable" ]; then
    groups="mutable,immutable"
else
    groups="immutable"
fi

# find the openssl config file if not provided
if [ "$#" -eq 4 ]; then
    openssl_config_file="$4"
else
    # find the openssl config file in the repos/openssl directory
    root="$(cd "$(dirname "$0")" && cd .. && pwd)"
    openssl_dir="$root/repos/openssl"
    openssl_config_file=$(find "$openssl_dir" -name "openssl.cnf" | head -n 1)
    if [ ! -f "$openssl_config_file" ]; then
        echo "OpenSSL config file not found. Please provide one."
        exit 1
    fi
fi

# create a key and certificate request
if [ "$container_type" = "compose" ]; then
    work_dir=$(dirname "$0")/compose-openssl-node
else
    work_dir=$(dirname "$0")/openssl-${container_type}
fi
mkdir -p "$work_dir"
cd "$work_dir"

openssl genrsa -out "$username.key" 2048
openssl req -config "$openssl_config_file" -new -key "$username.key" -out "$username.csr" -subj "/CN=$username"

if [ "$container_type" = "compose" ]; then
    ca_crt="/root/ca/riakca.ca.crt.pem"
    ca_key="/root/ca/riakca.ca.key.pem"
else
    ca_crt="/root/rt/riak/openriak/dev/ca/riakca.ca.crt.pem"
    ca_key="/root/rt/riak/openriak/dev/ca/riakca.ca.key.pem"
fi

# send the request to the container to get a certificate
docker exec -it "$container_name" openssl x509 -req -in "/var/run/riak/$username.csr" -CA "$ca_crt" -CAkey "$ca_key" -CAcreateserial -out "$username.crt" -days 3650 -sha256
docker exec -it "$container_name" mv "$username.crt" /var/run/riak/

docker exec -it "$container_name" cp -f "$ca_crt" /var/run/riak/

# add the user/certificate to the container
docker exec -it "$container_name" riak admin security add-user "$username" groups="$groups"
docker exec -it "$container_name" riak admin security add-source "$username" 0.0.0.0/0 certificate

# create a pkcs8 PEM file for the user
cat "$username.crt" "$username.key" > "$username.pem"
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in "$username.pem" -out "$username.pkcs8.pem"
cat "$username.crt" >> "$username.pkcs8.pem"

cd -
