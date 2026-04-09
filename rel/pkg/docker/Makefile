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
.PHONY: build connect-cluster clean rm rmi cluster stop stop-cluster compose-up compose-down compose-logs compose-status compose-verify-wg deep-clean help check-security-tls

tag ?= latest
base_image ?= $(shell grep '^ARG BASE_IMAGE=' Dockerfile | head -1 | cut -d'=' -f2)
os_tag = $(shell echo "$(base_image)" | sed 's/.*\///' | sed 's/:/_/g')
enable_security ?= false
enable_tls ?= false
enable_wireguard ?= false

# Build the docker-compose command with optional WireGuard overlay
COMPOSE_FILES := -f docker-compose.yml
ifeq ($(enable_wireguard),true)
COMPOSE_FILES += -f docker-compose.wireguard.yml
endif
COMPOSE_CMD = ENABLE_SECURITY=$(enable_security) ENABLE_TLS=$(enable_tls) OS_TAG=$(os_tag) TAG=$(tag) docker-compose $(COMPOSE_FILES)

.DEFAULT_GOAL := help

help:
	@echo "Riak Docker Makefile - available targets"
	@echo
	@echo "Variables:"
	@echo "  tag=$(tag)"
	@echo "  base_image=$(base_image)"
	@echo "  os_tag=$(os_tag)"
	@echo "  enable_security=$(enable_security)"
	@echo "  enable_tls=$(enable_tls)"
	@echo "  enable_wireguard=$(enable_wireguard)"
	@echo
	@echo "Targets:"
	@echo "  help              - Show this help"
	@echo "  build             - Build the Docker images (use base_image=... to change base)"
	@echo "  cluster           - Create and start cluster container (builds images if needed)"
	@echo "  stop              - Stop cluster container"
	@echo "  stop-cluster      - Stop only the cluster container"
	@echo "  connect-cluster   - Exec into the running cluster container"
	@echo "  rm                - Remove stopped containers"
	@echo "  compose-up        - Start multi-node cluster using Docker Compose"
	@echo "  compose-down      - Stop and remove Docker Compose cluster"
	@echo "  compose-logs      - Show logs from Docker Compose cluster"
	@echo "  compose-status    - Show status of Docker Compose cluster"
	@echo "  compose-verify-wg - Verify WireGuard encryption (requires enable_wireguard=true)"
	@echo "  rmi               - Remove the images and build marker"
	@echo "  clean             - Remove images and run files"
	@echo "  deep-clean        - Clean all artifacts including repos"
	@echo
	@echo "Examples:"
	@echo "  make build"
	@echo "  make build base_image=rockylinux:9"
	@echo "  make build tag=2102"
	@echo "  make cluster                                        # plain HTTP, no auth (default)"
	@echo "  make cluster enable_tls=true                        # HTTPS, no auth"
	@echo "  make cluster enable_security=true enable_tls=true   # HTTPS + auth"
	@echo "  make connect-cluster"
	@echo "  make compose-up"
	@echo "  make compose-up enable_tls=true"
	@echo "  make compose-up enable_security=true enable_tls=true"
	@echo "  make compose-up enable_wireguard=true"
	@echo "  make compose-up enable_wireguard=true enable_security=true enable_tls=true"
	@echo ""
	@echo "Note: enable_security=true requires enable_tls=true (Riak blocks non-TLS auth)."

# Riak security requires TLS: 
# Reject invalid combination early rather than starting an unusable cluster.
check-security-tls:
	@if [ "$(enable_security)" = "true" ] && [ "$(enable_tls)" != "true" ]; then \
		echo "====================================================="; \
		echo "ERROR: enable_security=true requires enable_tls=true."; \
		echo "====================================================="; \
		exit 1; \
	fi

cluster: check-security-tls .built
	mkdir -p run/logs run/lib run/openssl-cluster repos
	rm -rf run/openssl-cluster/*
	# 10017 is pb, 10018 is http
	-docker create --name=riak-$(os_tag)-cluster-$(tag) -v$$(pwd)/run/openssl-cluster:/var/run/riak -v$$(PWD)/repos:/root/src -p8888:8888 -p10017:10017 -p10018:10018 -e ENABLE_SECURITY=$(enable_security) -e ENABLE_TLS=$(enable_tls) riak-$(os_tag)-standalone-cluster:$(tag)
	docker start riak-$(os_tag)-cluster-$(tag)
	@echo "########################################################"
	@echo "cluster started"
	@echo "cluster port: 8888"
	@echo "cluster pb port: 10017"
	@echo "cluster http/https port: 10018 (https only when enable_tls=true)"
	@echo "enable_security=$(enable_security) enable_tls=$(enable_tls)"
	@echo "########################################################"

stop: stop-cluster

stop-cluster:
	-docker stop riak-$(os_tag)-cluster-$(tag)

build: rmi .built
	@echo "built"

shallow-build: .built
	@echo "built (shallow)"

rm: stop
	-docker rm riak-$(os_tag)-cluster-$(tag)
	-docker rm riak-$(os_tag)-node-$(tag)

rmi: rm
	-docker image rm riak-$(os_tag)-standalone-cluster:$(tag)
	-docker image rm riak-$(os_tag)-standalone-node:$(tag)
	-rm -f .built

connect-cluster:
	docker exec -it riak-$(os_tag)-cluster-$(tag) bash

# Docker Compose targets for multi-node cluster
compose-up: check-security-tls .built
	mkdir -p run/logs run/lib
	mkdir -p run/compose-openssl-node
ifeq ($(enable_wireguard),true)
	./wireguard/generate_keys.sh
endif
	$(COMPOSE_CMD) up -d
	@echo "########################################################"
	@echo "Multi-node cluster starting..."
	@echo "This may take up to 60 seconds to fully initialize"
ifeq ($(enable_wireguard),true)
	@echo "WireGuard: ENABLED (inter-node traffic encrypted)"
	@echo "WireGuard IPs: 10.0.0.1 - 10.0.0.5"
else
	@echo "WireGuard: disabled"
endif
	@echo "Node ports:"
	@echo "  Node 1: HTTP=10018, PB=10017, Admin=8881"
	@echo "  Node 2: HTTP=10028, PB=10027, Admin=8882"
	@echo "  Node 3: HTTP=10038, PB=10037, Admin=8883"
	@echo "  Node 4: HTTP=10048, PB=10047, Admin=8884"
	@echo "  Node 5: HTTP=10058, PB=10057, Admin=8885"
	@echo "Network: riaknet"
	@echo "########################################################"

compose-down:
	$(COMPOSE_CMD) down -v
	docker network rm riaknet 2>/dev/null || true
	rm -rf run/compose-openssl-node
	rm -rf run/wireguard

compose-logs:
	$(COMPOSE_CMD) logs -f

compose-verify-wg:
	@./wireguard/verify_encryption.sh

compose-status:
	@echo "Docker Compose Cluster Status:"
	@echo "============================="
	$(COMPOSE_CMD) ps
	@echo ""
	@echo "Cluster Status (if available):"
	@echo "=============================="
	-docker exec riak-compose-node-1 /root/riak_node/bin/riak admin cluster status 2>/dev/null || echo "Cluster not ready yet"

.scripts:
	mkdir -p run
	sed -e 's/#TAG#/$(tag)/g' -e 's/#OS_TAG#/$(os_tag)/g' img/scripts/get.sh > run/get.sh
	chmod +x run/get.sh
	sed -e 's/#TAG#/$(tag)/g' -e 's/#OS_TAG#/$(os_tag)/g' img/scripts/put.sh > run/put.sh
	chmod +x run/put.sh
	sed -e 's/#TAG#/$(tag)/g' -e 's/#OS_TAG#/$(os_tag)/g' img/scripts/del.sh > run/del.sh
	chmod +x run/del.sh
	sed -e 's/#TAG#/$(tag)/g' -e 's/#OS_TAG#/$(os_tag)/g' img/scripts/status.sh > run/status.sh
	chmod +x run/status.sh
	sed -e 's/#TAG#/$(tag)/g' -e 's/#OS_TAG#/$(os_tag)/g' img/scripts/request_cert.sh > run/request_cert.sh
	chmod +x run/request_cert.sh
	touch .scripts

.built: .scripts Dockerfile
	docker build --target cluster_dev_image --build-arg BASE_IMAGE=$(base_image) -t riak-$(os_tag)-standalone-cluster:$(tag) .
	docker build --target cluster_node_image --build-arg BASE_IMAGE=$(base_image) -t riak-$(os_tag)-standalone-node:$(tag) .
	touch .built

clean: rmi
	-rm -rf run
	-rm -f .built
	-rm -f .scripts

deep-clean: clean
	-rm -rf repos
