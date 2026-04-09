# Running riak_test with the Cluster Image

This guide explains how to use the cluster image to run the `riak_test` suite.

## Overview

The `riak_test` framework is Riak's comprehensive integration testing system that tests Riak functionality across multiple nodes. The cluster image supports a specialized mode for running `riak_test` that:

- Builds all 8 available nodes (instead of the default 5)
- Disables security for compatibility with test expectations
- Uses the original development configuration files
- Automatically commits changes to local git for test framework requirements

## Prerequisites

1. **Start the cluster container**:
   ```bash
   make cluster
   ```

2. **Connect to the cluster container**:
   ```bash
   make connect-cluster
   ```

## Quick Start

### 1. Deploy for riak_test

Inside the cluster container, use the `-t` flag to deploy specifically for `riak_test`:

```bash
./deploy.sh -t
```

This command will:
- Deploy all 8 nodes (dev1-dev8) instead of the default 5
- Disable security (`ENABLE_SECURITY=false`)
- Disables TLS
- Automatically commit changes to the local git repository
- **Not start the nodes** (riak_test manages node lifecycle)

### 2. Run riak_test

After deployment, you can run the riak_test suite:

```bash
cd /root/riak_test
rebar3 as prod compile # if not yet compiled
./riak_test -c riak -t <test_name>
```

## Understanding the -t Flag

The `-t` flag modifies the deployment behavior in several key ways:

### Node Configuration
- **Standard deployment**: Uses 5 nodes
- **riak_test deployment**: Uses all 8 nodes

### Security and TLS
- **Standard deployment**: Security and TLS enabled by default
- **riak_test deployment**: Security and TLS disabled by default

### Node Management
- **Standard deployment**: Automatically starts nodes and forms cluster
- **riak_test deployment**: Nodes are deployed but not started (riak_test controls lifecycle)

### Git Integration
- **Standard deployment**: Manual git commit required for test suite
- **riak_test deployment**: Automatic git commit with "Sync" message

## Configuration Details

### riak_test Configuration File

The cluster image includes a pre-configured `.riak_test.config` file located at `/root/.riak_test.config`:

```erlang
{default, [
    {platform,          "centos-64"},
    {tls,               false},
    {conn_fail_time,    30000},
    {load_workers,      10},
    {rt_harness,        rtdev},
    {rt_max_wait_time,  600000},
    {rt_retry_delay,    1500},
    {rt_scratch_dir,    "/tmp/riak_test_scratch"},
    {features,          [wday_test_data]}
]}.

{riak, [
    {rt_project, "riak"},
    {rtdev_path, [
        {root,             "/root/rt/riak"},
        {current,          "/root/rt/riak/openriak"}
    ]}
]}.
```

### Node Locations

After deployment with `-t`, the 8 development nodes are available at:
- `/root/rt/riak/openriak/dev/dev1`
- `/root/rt/riak/openriak/dev/dev2`
- ...
- `/root/rt/riak/openriak/dev/dev8`

## Development Workflow with riak_test

### 1. Make Code Changes

Follow the standard development workflow to make changes to your Riak code:

```bash
cd riak/_checkouts
ln -s $HOME/src/<your-repo> .
# Make your changes...
```

### 2. Deploy for Testing

Deploy your changes specifically for riak_test:

```bash
./deploy.sh -t
```

### 3. Run Specific Tests

Run individual tests to verify your changes:

```bash
cd /root/riak_test
./riak_test -c riak -t your_test_name
```

## Switching Between Modes

You can switch between standard development and riak_test modes:

### Switch to riak_test Mode
```bash
./deploy.sh -t
```

### Switch Back to Development Mode
```bash
./deploy.sh -n 5
./start_nodes.sh
./create_cluster.sh
./enable_security.sh
```

## Integration with Development Workflow

The riak_test functionality integrates seamlessly with the existing development workflow:

1. **Development Phase**: Use standard `./deploy.sh` for interactive development
2. **Testing Phase**: Use `./deploy.sh -t` for comprehensive testing
3. **Iteration**: Switch between modes as needed during development

This allows you to develop interactively with a secure, TLS-enabled cluster, then quickly switch to a test-compatible configuration for running the full test suite.

## See Also

- [Development Guide](DEVELOPMENT.md) - General development workflow
- [Main README](README.md) - Complete container documentation
- [Client Usage Guide](CLIENT_USAGE.md) - Client interaction examples
