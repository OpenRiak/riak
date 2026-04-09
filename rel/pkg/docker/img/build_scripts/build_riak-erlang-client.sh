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

# Build script for riak-erlang-client
# This script clones and builds riak-erlang-client from the OpenRiak repository

set -o errexit
set -o errtrace
set -o pipefail

version_file=/root/build_scripts/riak-erlang-client.version

if [[ ! -f "$version_file" ]]; then
    echo "Error: Missing $version_file"
    exit 1
fi

# shellcheck source=/dev/null
source "$version_file"

if [[ -z "$version" || -z "$url" ]]; then
    echo "Error: Missing version or url in $version_file"
    exit 1
fi

echo "Building riak-erlang-client $version"
sleep 5

# Clone or update riak-erlang-client repository
if [[ -d "riak-erlang-client" ]]; then
    echo "riak-erlang-client directory exists, updating..."
    cd riak-erlang-client
    git fetch origin
    git checkout $version
    git pull origin $version
    cd ..
else
    echo "Cloning riak-erlang-client repository..."
    git clone -b $version $url riak-erlang-client
fi

cd riak-erlang-client

# Clean any previous builds
rm -rf _build

# Compile riak-erlang-client
echo "Compiling riak-erlang-client..."
./rebar3 compile

cd ..

echo "riak-erlang-client $version built successfully"
sleep 5