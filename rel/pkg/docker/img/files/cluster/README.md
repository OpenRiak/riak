
# Using this container

## 1. Start Riak Nodes
Inside the container, start the development nodes:
```bash
./start_nodes.sh
```
This script stops any existing nodes and starts nodes dev1-dev5.

## 2. Form a Cluster
Create a 5-node Riak cluster:
```bash
./create_cluster.sh
```
This script joins all nodes together and shows the cluster status.
It also creates a convenient `riak` command symlink.

## 3. Verify Cluster Status (Optional)
```bash
riak admin cluster status
```
You should see all 5 nodes as active members of the cluster.

## 4. Enable Security (optional)
Security and TLS are disabled by default (plain HTTP, no auth). Security
**requires TLS**, so `enable_security.sh` errors out unless `ENABLE_TLS=true`:
```bash
ENABLE_SECURITY=true ENABLE_TLS=true ./enable_security.sh
```
This sets up test user groups, test users, and authentication methods (both
password and certificate). It includes a test request to verify security is
working. (Note: enabling TLS this way also requires restarting the nodes with
`ENABLE_TLS=true` so the HTTPS listener is active.)

## 5. Test Basic Operations
Use the provided helper scripts to test CRUD operations. The helper scripts
pick `http` or `https` automatically based on `ENABLE_TLS`.

With the default configuration (no security), the user argument is ignored by
the server. When security is enabled, use one of the users below (each has
different permissions):

- **riakadmin**: Full access user with read/write/delete permissions (password: 123456)
- **readonly**: Read-only user, can only retrieve data (password: 123456)  
- **riakwriteclient**: Full access user (certificate authentication)
- **riakreadclient**: Read-only user (certificate authentication)

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

## 6. Advanced Client Testing
Use the Erlang Protocol Buffers client for more advanced testing:
```bash
escript client_test.escript put test-bucket my-key "Hello from PB client"
escript client_test.escript get test-bucket my-key
escript client_test.escript del test-bucket my-key
```
This uses the *riakwriteclient* user account.
