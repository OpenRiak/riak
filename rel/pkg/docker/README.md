# Docker images for Standalone Riak Environments

This repository provides a multi-stage Docker build system for creating Riak
development and runtime environments. The Dockerfile creates two distinct images:

- **`cluster_dev_image`** - Full development environment with all build tools, testing frameworks, and source code
- **`cluster_node_image`** - Minimal runtime image containing only a single Riak node, used for Compose cluster

## Table of Contents

- [Docker Images](#docker-images)
  - [► cluster_dev_image (Development Environment)](#-cluster_dev_image-development-environment)
  - [► cluster_node_image (Runtime Environment)](#-cluster_node_image-runtime-environment)
- [Makefile targets](#makefile-targets)
  - [► cluster](#-cluster)
  - [► stop](#-stop)
  - [► stop-cluster](#-stop-cluster)
  - [► compose-up](#-compose-up)
  - [► compose-down](#-compose-down)
  - [► compose-logs](#-compose-logs)
  - [► compose-status](#-compose-status)
  - [► build](#-build)
  - [► rm](#-rm)
  - [► rmi](#-rmi)
  - [► connect-cluster](#-connect-cluster)
  - [► clean](#-clean)
  - [► deep-clean](#-deep-clean)
- [Starting Containers](#starting-containers)
  - [► Development Environment (cluster_dev_image)](#-development-environment-cluster_dev_image)
  - [► Multi-Node Cluster Environment (Docker Compose)](#-multi-node-cluster-environment-docker-compose)
  - [► WireGuard Encrypted Inter-Node Communication](#-wireguard-encrypted-inter-node-communication)
  - [► Managing the Docker Compose Cluster](#-managing-the-docker-compose-cluster)
- [Available user accounts](#available-user-accounts)
- [Client Usage Guide](#client-usage-guide)
- [Development Guide](#development-guide)
- [riak_test Guide](#riak_test-guide)
- [Using CRUD operations from outside the container](#using-crud-operations-from-outside-the-container)
- [Using the container from within the container](#using-the-container-from-within-the-container)
  - [► Development Environment (cluster_dev_image)](#-development-environment-cluster_dev_image-1)
- [Cluster Image Files](#cluster-image-files)
  - [► Build Scripts](#-build-scripts)
  - [► configure_build.sh](#-configure_buildsh)
  - [► riak_test.config](#-riak_testconfig)
  - [► client_test.escript](#-client_testescript)
  - [► initialize_container.sh](#-initialize_containersh)
  - [► start_nodes.sh](#-start_nodessh)
  - [► stop_nodes.sh](#-stop_nodessh)
  - [► create_cluster.sh](#-create_clustersh)
  - [► enable_security.sh](#-enable_securitysh)
  - [► get.sh](#-getsh)
  - [► put.sh](#-putsh)
  - [► del.sh](#-delsh)
  - [► deploy.sh](#-deploysh)
  - [► README.md](#-readmemd)
- [Node Image Files](#node-image-files)
  - [► initialize_container.sh](#-initialize_containersh-1)
  - [► start.sh](#-startsh)
  - [► stop.sh](#-stopsh)
  - [► enable_security.sh](#-enable_securitysh-1)
  - [► setup_wireguard.sh](#-setup_wireguardsh)
  - [► start_primary_node.sh](#-start_primary_nodesh)
  - [► start_joining_node.sh](#-start_joining_nodesh)
  - [► finalize_cluster.sh](#-finalize_clustersh)
  - [► keep_running.sh](#-keep_runningsh)
- [WireGuard Files](#wireguard-files)
  - [► generate_keys.sh](#-generate_keyssh)
  - [► docker-compose.wireguard.yml](#-docker-composewireguardyml)
- [External Scripts](#external-scripts)
  - [► status.sh](#-statussh)
  - [► get.sh](#-getsh-1)
  - [► put.sh](#-putsh-1)
  - [► del.sh](#-delsh-1)
  - [► request_cert.sh](#-request_certsh)

## Docker Images

### ► cluster_dev_image (Development Environment)
The full development image includes:
- Complete Riak cluster (5 nodes: dev1-dev5 [8 available])
- All build tools and dependencies (OpenSSL, OTP, rebar3)
- Testing frameworks (riak_test, client_test.escript)
- Source repositories for all components
- Cluster management scripts
- Security configuration tools

**Use this image for:**
- Development and testing
- Running a full 5-node Riak cluster in one container
- Integration testing with client libraries

### ► cluster_node_image (Runtime Environment)
The minimal runtime image includes:
- Single Riak node (stripped from dev1)
- No build tools or source code
- No testing frameworks

**Use this image for:**
- Production-like deployments
- Single-node setups
- Container orchestration (Docker Compose, Kubernetes)
- Scenarios where you need multiple independent Riak instances

## Makefile targets

### ► cluster
Creates and starts a cluster container using the `cluster_dev_image`.
Will build the image if not yet built. This creates a 5-node Riak cluster
(in a single container) with full development tools.
**Ports:** 8888, 10017, 10018

### ► stop
Stops the cluster container.

### ► stop-cluster
Stops only the cluster container.

### ► compose-up
Creates and starts a multi-node cluster using Docker Compose with the `cluster_node_image`.
Will build the image if not yet built. This creates a 5-node Riak cluster using individual node containers.

**Network:** riaknet

**Ports:**
- Node 1: HTTP=10018, PB=10017, Admin=8881
- Node 2: HTTP=10028, PB=10027, Admin=8882
- Node 3: HTTP=10038, PB=10037, Admin=8883
- Node 4: HTTP=10048, PB=10047, Admin=8884
- Node 5: HTTP=10058, PB=10057, Admin=8885

**WireGuard mode:**
When `enable_wireguard=true` is set, inter-node communication is encrypted via WireGuard tunnels.
See [WireGuard Encrypted Inter-Node Communication](#-wireguard-encrypted-inter-node-communication) for details.

### ► compose-down
Stops and removes the Docker Compose multi-node cluster. Also cleans up any WireGuard key material.

### ► compose-logs
Shows logs from all nodes in the Docker Compose cluster.

### ► compose-status
Shows the status of the Docker Compose cluster and Riak cluster status.

### ► build
Builds Docker images based on the specified base OS and copies needed files.
The multi-stage Dockerfile creates two images:
- `cluster_dev_image` (development environment)
- `cluster_node_image` (minimal runtime)

#### Available variables:
  * base_image
  * tag
  * enable_security (default: false) - password/certificate auth (see below)
  * enable_tls (default: false) - TLS/HTTPS client interface (see below)
  * enable_wireguard (default: false) - see [WireGuard section](#-wireguard-encrypted-inter-node-communication)

> **Defaults:** Out of the box the cluster serves **plain HTTP** on port 10018
> with **no authentication**. Both TLS and security are opt-in runtime
> environment toggles (`ENABLE_SECURITY` / `ENABLE_TLS`), applied when the
> container starts.
>
> **`enable_security=true` requires `enable_tls=true`.** Riak blocks any
> authenticated request that is not sent over TLS, so security cannot function
> without the HTTPS listener - the two are enabled together or not at all. The
> Makefile and the startup scripts reject `enable_security=true` with
> `enable_tls=false` as a misconfiguration. `enable_tls=true` on its own is
> valid (encrypted transport with anonymous access).

**Default build (builds both images using CentOS Stream 9):**
```bash
make build
```

**Build specific image stage:**
```bash
# Build only the development environment
docker build --target cluster_dev_image -t riak-dev:latest .

# Build only the minimal runtime
docker build --target cluster_node_image -t riak-node:latest .
```

**Build with a different base image (RHEL family only):**
```bash
make build base_image=rockylinux:9
make build base_image=almalinux:9
make build base_image=quay.io/centos/centos:stream9
```

**Set base image as environment variable:**
```bash
export base_image=rockylinux:9
make build
```

The `base_image` variable determines:
- Which Linux distribution to use as the foundation
- The naming of the resulting Docker image (includes the OS in the tag)
- Container names (will include the OS identifier)

**Note:** The base image must be compatible with `dnf` package manager (RHEL-based
distributions like CentOS, Rocky Linux, AlmaLinux, etc.).

#### Set a tag other than `latest`

The Docker image tag is controlled via the `tag` Makefile variable (default: `latest`).

Examples:
```bash
make build                      # uses tag=latest
make build tag=2102             # override tag for this build
export tag=mydev && make build  # override via env var
```

The tag is used by the Makefile to identify which image to build, run, or clean.

**Complete workflow examples:**
```bash
# Development workflow (5-node cluster in single container)
make cluster                    # Build and start cluster
make connect-cluster            # Connect to cluster container
# ... do work ...
make stop-cluster               # Stop cluster

# Multi-node distributed cluster workflow (Docker Compose)
make compose-up                 # Start 5-node cluster (ports: see below)
make compose-status             # Check cluster status
# ... work with distributed cluster ...
make compose-down               # Stop and remove cluster

# WireGuard encrypted cluster workflow
make compose-up enable_wireguard=true   # Start with encrypted inter-node traffic
make compose-status                     # Check cluster status
# ... inter-node traffic is encrypted via WireGuard tunnels ...
make compose-down                       # Stop, remove cluster, clean WG keys
```

### ► rm
Stops and removes the cluster container.

### ► rmi
Removes the built images.

### ► connect-cluster
Connect to the running single-container cluster container from another terminal.

### ► clean
Removes the images and 'run' files

### ► deep-clean
Removes the images and cleans all intermediate build data including downloaded repositories

## Starting Containers

### ► Development Environment (cluster_dev_image)
For the full development environment with a 5-node, single-container cluster:
```bash
make cluster
```
This creates and launches the cluster container using the `cluster_dev_image`.
The startup process will start 5 Riak nodes and form a cluster with them.
By default the cluster serves **plain HTTP** with **no authentication**. The
following scripts are automatically run:

1. `start_nodes.sh`
2. `create_cluster.sh`
3. `enable_security.sh` (a no-op unless `enable_security=true`)

**Cluster Ports:** 8888, 10017, 10018

**Security and TLS Control:**
Both are disabled by default. Valid combinations:
```bash
make cluster                                        # plain HTTP, no auth (default)
make cluster enable_tls=true                        # HTTPS transport, no auth
make cluster enable_security=true enable_tls=true   # HTTPS + password/cert auth
```
When `enable_security=false` the `enable_security.sh` script exits immediately.
`enable_security=true` requires `enable_tls=true` - Riak blocks all
authenticated requests that are not over TLS, so the combination
`enable_security=true enable_tls=false` is rejected as a misconfiguration.

### ► Multi-Node Cluster Environment (Docker Compose)
For a distributed multi-node cluster using individual node containers:
```bash
make compose-up
```
This creates and launches a 5-node Riak cluster using Docker Compose with the `cluster_node_image`.
Each node runs in its own container on the `riaknet` network. The cluster formation process:

1. Node 1 starts first
2. Nodes 2-5 start sequentially and join node 1
3. Node 5 commits the cluster plan
4. All nodes are connected in a distributed cluster

**Compose Cluster Ports:**
- Node 1: HTTP=10018, PB=10017, Admin=8881
- Node 2: HTTP=10028, PB=10027, Admin=8882
- Node 3: HTTP=10038, PB=10037, Admin=8883
- Node 4: HTTP=10048, PB=10047, Admin=8884
- Node 5: HTTP=10058, PB=10057, Admin=8885

**Security and TLS Control:**
Both are disabled by default. Valid combinations:
```bash
make compose-up                                       # plain HTTP, no auth (default)
make compose-up enable_tls=true                       # HTTPS transport, no auth
make compose-up enable_security=true enable_tls=true  # HTTPS + password/cert auth
```
`enable_security=true` requires `enable_tls=true`.

### ► WireGuard Encrypted Inter-Node Communication

The Docker Compose cluster supports an optional WireGuard mode that encrypts all
inter-node Riak traffic (Erlang distribution, handoff, ring gossip) through
WireGuard tunnels. Client access (HTTP/PB) continues to work exactly as before.

**Prerequisites:**
- `wireguard-tools` installed on the host machine:
  ```bash
  # macOS
  brew install wireguard-tools

  # Linux (RHEL/CentOS)
  dnf install epel-release && dnf install wireguard-tools

  # Linux (Debian/Ubuntu)
  apt install wireguard-tools
  ```

**Start a WireGuard-encrypted cluster:**
```bash
make compose-up enable_wireguard=true
```

This will:
1. Generate WireGuard key pairs and per-node configs (`run/wireguard/`)
2. Start the 5-node cluster with WireGuard overlay
3. Each container brings up a `wg0` interface before starting Riak
4. Riak nodes communicate via WireGuard tunnel IPs (10.0.0.1 - 10.0.0.5)
5. EPMD and Erlang distribution are bound to the WireGuard interface only

**Stop the cluster:**
```bash
make compose-down
```
This cleans up containers, network, and WireGuard key material.

**Verify WireGuard is working:**
```bash
# Check WireGuard interface status
docker exec riak-compose-node-1 wg show
docker exec riak-compose-node-1 ip addr show wg0

# Test WireGuard mesh connectivity
docker exec riak-compose-node-1 ping -c 3 10.0.0.2

# Verify Riak cluster uses WireGuard IPs
docker exec riak-compose-node-1 /root/riak/bin/riak admin cluster status
# Should show riak@10.0.0.1 through riak@10.0.0.5

# Client access still works on host ports (http by default, https with enable_tls=true)
curl http://localhost:10018/ping
```

**Combine with other options:**
```bash
make compose-up enable_wireguard=true enable_security=true enable_tls=true
```

**Network architecture:**
```
Each container has two interfaces:
  eth0 (172.20.0.1X) - Docker bridge, used for client access + WG endpoints
  wg0  (10.0.0.X)    - WireGuard tunnel, used for Riak inter-node traffic

Client traffic:  host:10018 → Docker port map → eth0:10018 → Riak HTTP listener
Inter-node:      riak@10.0.0.2 → wg0 → encrypted UDP → eth0 → peer eth0 → peer wg0
```

**Security hardening (for production single-NIC hosts):**

When WireGuard is enabled, the following Erlang settings are automatically configured
to ensure inter-node traffic cannot bypass the WireGuard tunnel:

- `ERL_EPMD_ADDRESS` is set to the WireGuard IP, so EPMD only listens on `wg0`
- `inet_dist_use_interface` is set in `advanced.config`, restricting Erlang
  distribution to accept connections only on `wg0`

This means on a single-NIC production host, only WireGuard UDP (port 51820)
needs to be open between nodes - EPMD (4369) and Erlang distribution ports
are unreachable from the physical network.

### ► Managing the Docker Compose Cluster

```bash
# Monitor cluster formation
make compose-logs

# Check cluster status
make compose-status

# Connect to specific nodes
docker exec -it riak-compose-node-1 bash
docker exec -it riak-compose-node-2 bash
# ... etc for nodes 3, 4, 5

# View cluster status
docker exec riak-compose-node-1 /root/riak_node/bin/riak admin cluster status

# Restart individual nodes
docker-compose restart riak-node-3

# Scale down/up (manual editing of docker-compose.yml required)
# See docker-compose.override.yml for examples

# WireGuard-specific diagnostics
docker exec riak-compose-node-1 wg show        # WireGuard tunnel status
docker exec riak-compose-node-1 ip addr show wg0  # WireGuard interface
docker exec riak-compose-node-1 ping -c 1 10.0.0.2  # Tunnel connectivity
```

## Available user accounts

When security is enabled (`enable_security=true enable_tls=true`), the startup
process creates some user accounts. Each account has different permissions:

- **riakadmin**: Full access user with read/write/delete permissions (password: 123456)
- **readonly**: Read-only user, can only retrieve data (password: 123456)
- **riakwriteclient**: Full access user with read/write/delete permissions (certificate auth)
- **riakreadclient**: Read-only user (certificate auth)

> With the default configuration (security disabled) no accounts are created
> and the cluster accepts unauthenticated requests over plain HTTP. Enabling
> security requires TLS (`enable_tls=true`); all authentication - password and
> certificate - happens over HTTPS.

## Client Usage Guide

For comprehensive examples of how to connect to and interact with Riak containers
using different client types (cURL, Java) and authentication methods
(username/password, client certificates), 
see the **[Client Usage Guide](CLIENT_USAGE.md)**.

The guide covers:
- Cluster container client examples
- Docker Compose cluster client examples
- Creating custom client certificates
- Java client installation instructions

## Development Guide

For information on how to use the cluster image for Riak development work,
see the **[Development Guide](DEVELOPMENT.md)**.

The guide covers:
- Setting up your development environment
- Using the _checkouts directory for code changes
- Iterative development workflow with deploy.sh
- Testing and debugging your changes
- Available development scripts and tools

**Note:** Development requires a `repos` directory on the host machine where you clone the repositories you want to work on. This directory is mounted into the container for development workflows.

## riak_test Guide

For information on how to use the cluster image to run the `riak_test` suite,
see the **[riak_test Guide](RIAK_TEST.md)**.

The guide covers:
- Using deploy.sh for riak_test compatibility
- Running comprehensive integration tests
- Understanding the differences between development and test modes
- Troubleshooting test failures
- Advanced riak_test configuration and usage

## Using CRUD operations from outside the container

**Applies to:** `cluster_dev_image` only

Part of the build process will create scripts in the local `run` directory.
These scripts can be used to interact with the running container.

> **Note:**
> If the container is not ready when running these commands, then the scripts in the `run`
> directory will print `Container not initialized yet. Please wait.`
> every 5 seconds until the container is ready, then automatically run your command.

### 1. Verify Cluster Status
```bash
./run/status.sh
```
You should see all 5 nodes as active members of the cluster.

### 2. Test Basic Operations

For the following commands use one of prebuilt user accounts.

**Store data:**
```bash
./run/put.sh riakadmin test-bucket my-key "Hello World"
```

**Retrieve data:**
```bash
./run/get.sh readonly test-bucket my-key
```

**Delete data:**
```bash
./run/del.sh riakadmin test-bucket my-key
```

## Using the container from within the container

### ► Development Environment (cluster_dev_image)

#### 1. Connect to the Cluster Container
```bash
make connect-cluster
```
Connect to the cluster container to run the remaining commands.

#### 2. Verify Cluster Status (Optional)
```bash
riak admin cluster status
```
You should see all 5 nodes as active members of the cluster.

#### 3. Test Basic Operations
Use the provided helper scripts to test CRUD operations:

For the following commands use one of prebuilt user accounts.

**Store data:**
```bash
./put.sh riakadmin test-bucket my-key "Hello World"
```

**Retrieve data:**
```bash
./get.sh readonly test-bucket my-key
```

**Delete data:**
```bash
./del.sh riakadmin test-bucket my-key
```

#### 4. Advanced Client Testing
Use the Erlang Protocol Buffers client for more advanced testing:
```bash
escript client_test.escript put test-bucket my-key "Hello from PB client"
escript client_test.escript get test-bucket my-key
escript client_test.escript del test-bucket my-key
```
This uses the *riakwriteclient* user account.

#### 5. Connect from Another Terminal
If you need multiple terminal sessions in the same cluster container:
```bash
make connect-cluster
```

## Cluster Image Files

The following files are located in the `img/files/cluster` directory and are copied into the Docker
container during the build process.

### ► Build Scripts
The build process is modularized into individual scripts located in `img/build_scripts/`:

- **build_openssl.sh**: Builds OpenSSL with custom configuration for Riak/OTP
- **build_otp.sh**: Builds Erlang/OTP with SSL support and optimized settings
- **build_riak.sh**: Clones and builds Riak from OpenRiak repository with 8 development releases
- **build_riak_test.sh**: Clones and builds riak_test framework from OpenRiak repository
- **build_riak-erlang-client.sh**: Clones and builds the Erlang client for Riak

### ► Version Files
__**Update the relevant file as needed**__

Located in `img/build_scripts/`, these files define the source location and version for each build
component:

- `openssl.version`
- `otp.version`
- `riak.version`
- `riak_test.version`
- `riak-erlang-client.version`

Each file uses simple shell variable assignments:

`version=...`

`url=...`

Each build script reads only its matching version file. This keeps Docker cache invalidation scoped to
the affected build step, so changing Riak-specific inputs does not force OpenSSL or OTP to rebuild.

### ► configure_build.sh
Configuration script that runs after individual components are built. It:
1. Sets up the build environment and PATH variables
3. Configures Riak with Docker-specific settings
4. Creates 8 development releases (dev1-dev8) for testing
5. Generates TLS certificates and client certificates for secure communication
6. Produces two `riak.conf` variants per node: the default plain-HTTP config and
   a `riak.conf.tls` HTTPS config. The runtime scripts select the HTTPS variant
   only when `ENABLE_TLS=true`; the plain-HTTP config is the default.

### ► riak_test.config
Configuration file for the Riak testing framework (`riak_test`). Defines:
- Platform settings
- Test environment paths and directories
- Runtime configuration parameters
- Connection and retry settings
- Feature flags for testing

### ► client_test.escript
Erlang escript for testing Riak client operations using the Protocol Buffers interface. Provides:
- TLS connection setup with certificate authentication
- Command-line interface for basic CRUD operations
- Support for PUT, GET, and DELETE operations on buckets/keys
- Error handling and usage information

### ► initialize_container.sh
Container initialization script that orchestrates the complete Riak setup process:
1. Starts the development nodes using `start_nodes.sh` (which selects the plain
   or TLS `riak.conf` variant based on `ENABLE_TLS`, default: false)
2. Forms a 5-node cluster using `create_cluster.sh`
3. Conditionally enables security features using `enable_security.sh` (controlled by `ENABLE_SECURITY` environment variable, default: false)
4. Copies TLS certificates to the shared volume only when `ENABLE_TLS=true`
5. Enters a monitoring loop that:
   - Checks for a shutdown signal file every 5 seconds
   - Exits gracefully when the shutdown file is detected
   - Removes the shutdown file before exiting

This script ensures the container is fully configured and ready for use when it starts up.

### ► start_nodes.sh
Node management script that:
- Stops all 8 development nodes (dev1-dev8)
- Selects the plain-HTTP or TLS `riak.conf` variant per node based on `ENABLE_TLS`
- Starts the first 5 nodes (dev1-dev5) as daemons

### ► stop_nodes.sh
Node management script that:
- Stops all 8 development nodes (dev1-dev8)

### ► create_cluster.sh
Cluster formation script that:
1. Verifies all 5 nodes are running and responsive
2. Joins nodes dev2-dev5 to dev1 to form a cluster
3. Plans and commits the cluster formation
4. Shows cluster status
5. Creates a convenient symlink to the riak command

### ► enable_security.sh
Security configuration script that sets up Riak's security features. It is a
no-op unless `ENABLE_SECURITY=true`, and **requires `ENABLE_TLS=true`** - if
security is requested without TLS the script errors out.
When enabled it:
1. Enables Riak security subsystem
2. Creates user groups (immutable, mutable) with appropriate permissions
3. Adds password-authenticated users (riakadmin, readonly)
4. Adds certificate-authenticated users/sources (riakwriteclient, riakreadclient)
5. Tests the security setup with a sample HTTPS request

### ► get.sh
HTTP client helper script for retrieving data from Riak:
- Takes user, bucket, and key as command-line arguments
- Uses cURL to make authenticated HTTPS GET requests
- Includes error handling and usage information
- Uses hardcoded password (123456) for demo purposes

### ► put.sh
HTTP client helper script for storing data in Riak:
- Takes user, bucket, key, and value as command-line arguments
- Uses cURL to make authenticated HTTPS PUT requests
- Sets appropriate Content-Type headers
- Uses hardcoded password (123456) for demo purposes

### ► del.sh
HTTP client helper script for deleting data from Riak:
- Takes user, bucket, and key as command-line arguments
- Uses cURL to make authenticated HTTPS DELETE requests
- Includes error handling and usage information
- Uses hardcoded password (123456) for demo purposes

### ► deploy.sh
Development deployment script for creating multiple Riak node releases:
- Takes optional `-n` parameter to specify number of nodes (default: 5)
- Takes optional `-t` parameter to deploy for riak_test (deploys all 8 nodes, disables security)
- Generates development node configurations and releases using rebar3
- Copies releases to the test environment directory
- Provides instructions for committing changes to git repository
- Usage: `deploy.sh [-n nodes] [-t] [-h]`

### ► README.md
Documentation file containing usage instructions and examples for the container environment.

## Node Image Files

The following files are located in the `img/files/node` directory and are copied into the node Docker image used by Docker Compose.

### ► initialize_container.sh
Node container initialization script that orchestrates the minimal Riak node setup process:
1. Starts the single Riak node using `start.sh`
2. Conditionally enables security features using `enable_security.sh` (controlled by `ENABLE_SECURITY` environment variable, default: false)
3. Copies TLS certificates to the shared volume only when `ENABLE_TLS=true`
4. Enters a monitoring loop that:
   - Checks for a shutdown signal file every 5 seconds
   - Exits gracefully when the shutdown file is detected
   - Removes the shutdown file before exiting

This script ensures the node container is configured and ready for use when it starts up.

### ► start.sh
Single node startup script that:
- Stops any existing Riak process
- Starts the Riak node as a daemon
- Verifies the node is responsive with ping checks
- Includes retry logic with up to 10 attempts
- Exits with error if node fails to start

### ► stop.sh
Simple node shutdown script that:
- Cleanly stops the running Riak node

### ► enable_security.sh
Security configuration script for node containers that sets up Riak's security
features. It **requires `ENABLE_TLS=true`** and errors out otherwise (Riak blocks
non-TLS authenticated requests). It:
1. Waits for the Riak ring to be ready
2. Enables Riak security subsystem
3. Creates user groups (immutable, mutable) with appropriate permissions
4. Adds password-authenticated users (riakadmin, readonly)
5. Adds certificate-authenticated users (riakwriteclient, riakreadclient) and sources
6. Tests the security setup with a sample HTTPS request

Note: This provides the same security setup as the cluster version but for a single node.
It is only invoked when `ENABLE_SECURITY=true`.

### ► setup_wireguard.sh
WireGuard interface setup script that runs inside a container before Riak starts.
No-op when `ENABLE_WIREGUARD` is not set to `true`. When active:
1. Reads the pre-generated WireGuard config from `/etc/wireguard/wg0.conf` (mounted volume)
2. Brings up the `wg0` interface using `wg-quick`
3. Falls back to `wireguard-go` userspace implementation if kernel module is unavailable
4. Verifies peer connectivity with retry logic
5. Merges `inet_dist_use_interface` into Riak's `advanced.config` using
   `merge_advanced_config.escript`, preserving all existing settings (logger,
   riak_core, riak_repl, etc.)
6. Validates that `ERL_EPMD_ADDRESS` is set (configured in docker-compose)

### ► merge_advanced_config.escript
Erlang escript that safely merges a key-value pair into a Riak `advanced.config` file.
Follows the same merge strategy as `riak_test`'s `rtdev:update_app_config_file/2`:
- Reads the existing config with `file:consult/1`
- Merges at both the application level and key level using `lists:keystore/4`
- New values replace existing values for the same key; all other settings are preserved
- Writes back with `io_lib:format("~0p.")

Usage: `escript merge_advanced_config.escript <config_file> <app> <key> <value>`

### ► start_primary_node.sh
Script for starting the primary (seed) node in a Docker Compose cluster.
Takes the node IP as argument, configures the Riak nodename, and calls `initialize_container.sh`.

### ► start_joining_node.sh
Script for starting a joining node in a Docker Compose cluster.
Takes the node IP, primary node IP, and an optional health-check IP as arguments.
Waits for the primary node to be ready, starts Riak, and joins the cluster with retry logic.

The optional third argument (`health_check_ip`) allows the HTTP health check to use
a different IP than the cluster join IP. This is used in WireGuard mode where the
cluster join uses the WireGuard IP but the health check uses the Docker bridge IP
for reliability during startup.

### ► finalize_cluster.sh
Script that runs on the last joining node to commit the cluster plan.
Waits for all expected nodes to appear in the cluster membership before committing.

### ► keep_running.sh
Simple loop that keeps a container running until a shutdown signal file is detected.
Used by joining nodes in Docker Compose mode.

## WireGuard Files

The following files support WireGuard encrypted inter-node communication for the
Docker Compose cluster. See [WireGuard section](#-wireguard-encrypted-inter-node-communication)
for usage instructions.

### ► generate_keys.sh
Located in `wireguard/`. Host-side script that generates WireGuard key pairs and
per-node `wg0.conf` configuration files. Run automatically by `make compose-up`
when `enable_wireguard=true`.

- Takes an optional node count argument (default: 5)
- Generates private/public key pairs for each node
- Creates complete `wg0.conf` files with full-mesh peer configuration
- Uses Docker bridge IPs (172.20.0.1X) as WireGuard endpoints
- Assigns WireGuard tunnel IPs (10.0.0.X) to each node
- Output written to `run/wireguard/node-N/wg0.conf`
- Requires `wireguard-tools` on the host (`brew install wireguard-tools`)

### ► docker-compose.wireguard.yml
Docker Compose overlay file that adds WireGuard capabilities to each container.
Used automatically when `enable_wireguard=true`. Adds:
- `NET_ADMIN` capability (kernel WireGuard uses netlink, no device mapping needed)
- WireGuard config volume mounts (read-only)
- `ERL_EPMD_ADDRESS` environment variable (binds EPMD to WireGuard interface)
- Overridden commands that call `setup_wireguard.sh` before Riak startup
- WireGuard IPs as Riak nodenames instead of Docker bridge IPs

## External Scripts

The following files are located in the `img/scripts` directory and are processed by
the Makefile to create executable scripts in the `run` directory.

### ► status.sh
Script template for checking cluster status from outside the container.

### ► get.sh
Script template for retrieving data from outside the container.

### ► put.sh
Script template for storing data from outside the container.

### ► del.sh
Script template for deleting data from outside the container.

### ► request_cert.sh
Script to request a client authentication certificate from a running container.
Takes a container type, username, and group as arguments.
Certificates are placed under `./run/openssl-cluster` or `./run/compose-openssl-node` depending on container type.

Usage: `./run/request_cert.sh <container_type> <username> <group> [<openssl_config_file>]`
- container_type: cluster, compose
- group: mutable, immutable
- openssl_config_file: optional

Examples:
- `./run/request_cert.sh cluster myuser mutable`
- `./run/request_cert.sh compose testuser immutable`

These script templates are processed by the Makefile to replace `#TAG#` placeholders with
the actual Docker tag and create executable scripts in the `run` directory.

