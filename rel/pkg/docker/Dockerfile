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
ARG BASE_IMAGE=quay.io/centos/centos:stream9
FROM ${BASE_IMAGE} AS cluster_dev_image
#FROM rockylinux:9

EXPOSE 8888 10017 10018

WORKDIR /root

RUN sh -c 'command -v dnf >/dev/null 2>&1 || { echo >&2 "ERROR: This Dockerfile requires a base image with dnf (RHEL-family: CentOS Stream/Rocky/Alma)."; exit 1; }'

RUN dnf -y update && dnf -y install which git autoconf m4 tar readline perl man \
    ncurses-devel cmake pam-devel rpm-build procps hostname shadow-utils util-linux net-tools \
    iproute iputils && \
    dnf -y install epel-release && \
    dnf -y install wireguard-tools || echo "NOTICE: wireguard-tools not available; WireGuard mode will require runtime install"

RUN mkdir -p /root/build_scripts

ADD img/files/cluster/initialize_container.sh /root/
ADD img/files/cluster/start_nodes.sh /root/
ADD img/files/cluster/stop_nodes.sh /root/
ADD img/files/cluster/create_cluster.sh /root/
ADD img/files/cluster/enable_security.sh /root/
ADD img/files/cluster/deploy.sh /root/
ADD img/files/cluster/client_test.escript /root/
ADD img/files/cluster/riak_test.config /root/.riak_test.config
ADD img/files/cluster/put.sh /root/
ADD img/files/cluster/del.sh /root/
ADD img/files/cluster/get.sh /root/
ADD img/files/cluster/README.md /root/

# Build components in order. Each step only depends on its own script and
# version file so later changes do not invalidate earlier cached layers.
ADD img/build_scripts/build_openssl.sh /root/build_scripts/
ADD img/build_scripts/openssl.version /root/build_scripts/
RUN /usr/bin/bash -c "./build_scripts/build_openssl.sh"
ADD img/build_scripts/build_otp.sh /root/build_scripts/
ADD img/build_scripts/otp.version /root/build_scripts/
RUN /usr/bin/bash -c "./build_scripts/build_otp.sh"
ADD img/build_scripts/build_riak.sh /root/build_scripts/
ADD img/build_scripts/riak.version /root/build_scripts/
RUN /usr/bin/bash -c "./build_scripts/build_riak.sh"
ADD img/build_scripts/build_riak_test.sh /root/build_scripts/
ADD img/build_scripts/riak_test.version /root/build_scripts/
RUN /usr/bin/bash -c "./build_scripts/build_riak_test.sh"
ADD img/build_scripts/build_riak-erlang-client.sh /root/build_scripts/
ADD img/build_scripts/riak-erlang-client.version /root/build_scripts/
RUN /usr/bin/bash -c "./build_scripts/build_riak-erlang-client.sh"

# Configure and finalize build
ADD img/build_scripts/configure_build.sh /root/build_scripts/
RUN /usr/bin/bash -c "./build_scripts/configure_build.sh"

ENTRYPOINT ["/usr/bin/bash", "/root/initialize_container.sh"]
#CMD ["bash", "-l"]

################################################################################

FROM cluster_dev_image AS cluster_node_image

RUN rm -rf /root/initialize_container.sh \
    /root/start_nodes.sh \
    /root/stop_nodes.sh \
    /root/create_cluster.sh \
    /root/enable_security.sh \
    /root/deploy.sh \
    /root/client_test.escript \
    /root/riak_test.config \
    /root/README.md \
    /root/build_scripts \
    /root/put.sh \
    /root/get.sh \
    /root/del.sh && \
    mv /root/rt/riak/openriak/dev/dev1/riak /root/riak_node && \
    mv /root/rt/riak/openriak/dev/ca /root/ && \
    mv /root/rt/riak/openriak/dev/client /root/ && \
    rm -rf /root/rt && \
    ln -fs /root/riak_node/bin/riak /usr/local/bin/riak

ADD img/files/node/start_primary_node.sh /root/
ADD img/files/node/start_joining_node.sh /root/
ADD img/files/node/finalize_cluster.sh /root/
ADD img/files/node/keep_running.sh /root/
ADD img/files/node/initialize_container.sh /root/
ADD img/files/node/enable_security.sh /root/
ADD img/files/node/setup_wireguard.sh /root/
ADD img/files/node/merge_advanced_config.escript /root/
ADD img/files/node/start.sh  /root/
ADD img/files/node/stop.sh /root/

ENTRYPOINT ["/usr/bin/bash", "/root/initialize_container.sh"]
