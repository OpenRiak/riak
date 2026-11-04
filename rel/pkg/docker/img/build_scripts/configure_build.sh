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

# Build script for Riak cluster development environment
# This script configures Riak dev releases with TLS and sets up the release directory

set -o errexit
set -o errtrace
set -o pipefail

# ============================================================================
# CREATE AND COPY DEV RELEASES
# ============================================================================

cd riak

for i in {1..8}; do
    ./rel/gen_tls_dev dev${i} rel/vars/dev_vars.config.src rel/vars/${i}_vars.config
    ./rebar3 as dev release -o dev/dev${i} --overlay_vars rel/vars/${i}_vars.config
done

# ============================================================================
# GENERATE TLS CERTIFICATES AND riak.conf VARIANTS
# ============================================================================
#
# TLS is opt-in at runtime via the ENABLE_TLS environment variable (default
# false).  gen_tls_devcerts generates the per-node certificates AND rewrites
# riak.conf in place to use the HTTPS listener + ssl.* settings.  We keep two
# explicit variants per node: riak.conf.notls (the plain-HTTP config, which
# ships as the default riak.conf) and riak.conf.tls (the HTTPS config).  The
# runtime start scripts select between them based on ENABLE_TLS.

echo "Generating TLS certificates and riak.conf variants"
for i in {1..8}; do
    etc="dev/dev${i}/riak/etc"
    # Snapshot the plain-HTTP config BEFORE gen_tls_devcerts rewrites riak.conf.
    cp "${etc}/riak.conf" "${etc}/riak.conf.notls"
    # gen_tls_devcerts generates the per-node certs and rewrites riak.conf in
    # place to use the HTTPS listener + ssl.* settings.
    ./rel/gen_tls_devcerts dev${i}
    # Preserve the HTTPS variant it produced, then restore plain HTTP as the
    # default active config. The runtime start scripts select between
    # riak.conf.notls (default) and riak.conf.tls based on ENABLE_TLS.
    # I know this is a roundabout way to do it. I'll plan on refactoring gen_tls_devcerts
    # but this works for now.
    cp "${etc}/riak.conf" "${etc}/riak.conf.tls"
    cp "${etc}/riak.conf.notls" "${etc}/riak.conf"
done
./rel/gen_tls_clientcert riakwriteclient
./rel/gen_tls_clientcert riakreadclient

echo "Copying dev releases"

# ============================================================================
# COPY RELEASES AND INITIALIZE GIT
# ============================================================================

# Setup release directory structure
mkdir -p $HOME/rt/riak/openriak/dev
cp -p -P -R dev $HOME/rt/riak/openriak/

# Initialize git repository for releases
cd $HOME/rt/riak
git config --global user.email "root@docker.local"
git config --global user.name "root docker"
git init
git add .
git commit -m"init"
cd $HOME

echo "Releases have been copied to $HOME/rt/riak"
echo
