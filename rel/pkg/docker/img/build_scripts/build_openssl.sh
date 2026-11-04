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

# Build script for OpenSSL
# This script builds OpenSSL with the configuration needed for Riak/OTP

set -o errexit
set -o errtrace
set -o pipefail

version_file=/root/build_scripts/openssl.version

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

echo "Building OpenSSL $version"
sleep 5

mkdir -p openssl
cd openssl

# Download the OpenSSL source code using curl
curl -L -o openssl-$version.tar.gz $url

# Extract the OpenSSL source code
tar -xzf openssl-$version.tar.gz
rm openssl-$version.tar.gz

# Build the OpenSSL source code
cd openssl-$version

# Configure OpenSSL with the settings from your command
./config --release --prefix=/opt/openssl --openssldir=/opt/openssl/ssl -Wl,-rpath,/opt/openssl/lib enable-ec_nistp_64_gcc_128 shared -Wno-implicit-function-declaration

# Build and install
make && make test && make install_sw

# Clean up
cd ..

echo "OpenSSL $version built and installed to /opt/openssl"
sleep 5
