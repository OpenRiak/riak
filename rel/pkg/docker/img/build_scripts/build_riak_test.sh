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

# Build script for riak_test
# This script clones and builds riak_test from the OpenRiak repository

set -o errexit
set -o errtrace
set -o pipefail

version_file=/root/build_scripts/riak_test.version

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

echo "Building riak_test $version"
sleep 5

# Clone or update riak_test repository
if [[ -d "riak_test" ]]; then
    echo "riak_test directory exists, updating..."
    cd riak_test
    git fetch origin
    git checkout $version
    git pull origin $version
    cd ..
else
    echo "Cloning riak_test repository..."
    git clone -b $version $url riak_test
fi

cd riak_test

# Clean any previous builds
rm -rf _build

# Compile riak_test
echo "Compiling riak_test..."
make

cd ..

echo "riak_test $version built successfully"
sleep 5
