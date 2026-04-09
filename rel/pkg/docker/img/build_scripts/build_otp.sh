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

# Build script for OTP
# This script builds OTP
# The link passed in is the link to the OTP source code

set -o errexit
set -o errtrace
set -o pipefail

version_file=/root/build_scripts/otp.version

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

echo "Building OTP $version"
sleep 5

mkdir -p otp
cd otp

# Download the OTP source code using curl
curl -L -o otp_src_$version.tar.gz $url

# Extract the OTP source code
tar -xzf otp_src_$version.tar.gz
rm otp_src_$version.tar.gz

# Build the OTP source code
cd otp_src_$version
export ERL_TOP=$PWD
# configure to use the openssl under /opt/openssl
export LD_LIBRARY_PATH=/opt/openssl/lib/
export PATH=/opt/openssl/bin:$PATH
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" >> /root/.bashrc
echo "export PATH=\"$PATH\"" >> /root/.bashrc

./configure --with-ssl=/opt/openssl --disable-dynamic-ssl-lib --without-megaco --without-odbc --disable-hipe --without-hipe --without-javac --without-jinterface --without-debugger --without-et
make && make release_tests && make install

# Clean up
cd ..

echo "OTP $version built and installed to /usr/local/lib/erlang/$version"
sleep 5