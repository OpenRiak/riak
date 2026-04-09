# Riak Development Guide - Cluster Image

This guide explains how to use the cluster image for Riak development work.

## Development Quickstart

### Host Machine Setup

1. **Clone the repository you want to work on** under the `repos` directory on your host machine:
   ```bash
   cd repos/
   git clone <your-repo-url>
   ```

2. **Checkout the branch you want to work on**:
   ```bash
   cd <your-repo>
   git checkout <your-branch>
   ```

3. **Start the cluster container**:
   ```bash
   make cluster
   ```

4. **Connect to the cluster container**:
   ```bash
   make connect-cluster
   ```

### Inside the Container

Once connected to the cluster container, follow these steps:

1. **Navigate to the riak directory**:
   ```bash
   cd riak
   ```

2. **Create the _checkouts directory** (if it doesn't exist):
   ```bash
   mkdir _checkouts
   ```

3. **Navigate to _checkouts**:
   ```bash
   cd _checkouts
   ```

4. **Create a symbolic link to your repository**:
   ```bash
   ln -s $HOME/src/<your-repo> .
   ```
   
   Example:
   ```bash
   ln -s $HOME/src/riak_core .
   ```

5. **Make your code changes** as needed using your preferred editor or IDE.
You can make the changes either within in the container or on the host.

6. **Return to the home directory**:
   ```bash
   cd $HOME
   ```

7. **Deploy your changes**:
   ```bash
   ./deploy.sh
   ```
   
   Your new code is now running in the cluster!
   
   Note that the deploy script will deploy 5 nodes by default. use `-n` to modify the number of nodes.

## Testing Your Changes

For information on how to test your changes with a client, see the [Client Usage README](CLIENT_USAGE.md).

For information on how to run the comprehensive `riak_test` suite with your changes,
see the [riak_test Guide](RIAK_TEST.md).

## Development Workflow Tips

### Iterative Development
- After making changes, simply run `./deploy.sh` again to rebuild and redeploy
- The deploy script will automatically stop existing nodes, rebuild with your changes, and restart the cluster

### Multiple Repositories
- You can symlink multiple repositories in the `_checkouts` directory
- Each repository you symlink will be used during the build process

### Branch Switching
- To switch branches, either use `git` inside the container or on the host machine.
- Run `./deploy.sh` after switching branches to rebuild with the new code

### Debugging
- Use `./start_nodes.sh` and `./stop_nodes.sh` to manually control the cluster
- Check logs in `/root/rt/riak/openriak/dev/dev*/riak/log/` for debugging information
- Use `./create_cluster.sh` to reform the cluster if needed
- Use `./enable_security.sh` to reenable security features if needed

## Available Scripts

The following development scripts are available in the cluster container:

- `./deploy.sh` - Deploy your changes (use `-t` flag for riak_test compatibility)
- `./start_nodes.sh` - Start all Riak nodes
- `./stop_nodes.sh` - Stop all Riak nodes  
- `./create_cluster.sh` - Form a cluster from running nodes
- `./enable_security.sh` - Enable Riak security features
## Environment Variables

The cluster respects the following environment variables:

- `ENABLE_SECURITY` - Enable/disable security features (default: false).
  Requires `ENABLE_TLS=true` - security without TLS is rejected as a misconfiguration.
- `ENABLE_TLS` - Enable/disable the TLS/HTTPS client interface (default: false).

Both are applied at container start. To enable security when reenabling manually
inside the container, export both variables first, e.g.
`ENABLE_SECURITY=true ENABLE_TLS=true ./enable_security.sh`.

## Troubleshooting

### Common Issues

**Problem**: Changes not reflected after deploy
- **Solution**: Ensure your repository is properly symlinked in `_checkouts`
- **Solution**: Check that you're in the correct branch

**Problem**: Cluster formation fails
- **Solution**: Run `./stop_nodes.sh` then `./start_nodes.sh` and `./create_cluster.sh`

**Problem**: Permission issues with repositories
- **Solution**: Ensure the `repos` directory on the host has proper permissions

### Getting Help

- Check the main [README.md](README.md) for general container usage
- See [CLIENT_USAGE.md](CLIENT_USAGE.md) for client testing examples
- Review container logs for detailed error information
