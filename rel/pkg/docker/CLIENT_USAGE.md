# Riak Client Usage Guide

This guide demonstrates how to interact with Riak containers using different client types and authentication methods.

> **Defaults (plain HTTP, no auth):** Unless you start the container with
> `enable_tls=true` and `enable_security=true`, the cluster serves **plain HTTP**
> with **no authentication**. In that default mode, drop the `-k`, `--cacert`,
> `--cert`, `--key`, and `-u user:pass` options and use `http://` instead of
> `https://`. For example:
>
> ```bash
> # Default mode (no TLS, no auth)
> $ curl -X POST http://127.0.0.1:10018/buckets/mybucket/keys/mykey -d 'some value'
> $ curl http://127.0.0.1:10018/buckets/mybucket/keys/mykey
> ```
>
> The examples below assume the cluster was started with **both**
> `enable_security=true` and `enable_tls=true` (username/password and
> certificate authentication over HTTPS). Security **requires** TLS.

## Table of Contents

- [Cluster Container (cluster_dev_image)](#cluster-container-cluster_dev_image)
  - [cURL with Username/Password](#curl-with-usernamepassword)
  - [cURL with Client Certificate](#curl-with-client-certificate)
  - [Java Client with Username/Password](#java-client-with-usernamepassword)
  - [Java Client with Client Certificate](#java-client-with-client-certificate)
- [Docker Compose Cluster](#docker-compose-cluster)
  - [cURL with Username/Password](#curl-with-usernamepassword-1)
  - [cURL with Client Certificate](#curl-with-client-certificate-1)
  - [Java Client with Username/Password](#java-client-with-usernamepassword-1)
  - [Java Client with Client Certificate](#java-client-with-client-certificate-1)
- [Creating Additional Client Certificates](#creating-additional-client-certificates)
- [Java Client Installation](#java-client-installation)

## Cluster Container (cluster_dev_image)

The cluster container runs on ports 8888, 10017, and 10018. SSL certificates are located in `run/openssl-cluster/`.

### cURL with Username/Password

**Store data (POST):**
```bash
$ curl -k --cacert run/openssl-cluster/riakca.ca.crt.pem -uriakadmin:123456 -X POST https://127.0.0.1:10018/buckets/mybucket/keys/mykey -d 'some value'
```

**Retrieve data (GET):**
```bash
$ curl -k --cacert run/openssl-cluster/riakca.ca.crt.pem -uriakadmin:123456 https://127.0.0.1:10018/buckets/mybucket/keys/mykey
```

### cURL with Client Certificate

**Retrieve data (GET):**
```bash
$ curl -k --cert run/openssl-cluster/riakwriteclient.crt.pem --key run/openssl-cluster/riakwriteclient.key.pem --cacert run/openssl-cluster/riakca.ca.crt.pem https://127.0.0.1:10018/buckets/mybucket/keys/mykey
```

### Java Client with Username/Password

```bash
$ ./interactive-riak-cli.sh -p 10017 --tls --ca-cert run/openssl-cluster/riakca.ca.crt.pem --username riakadmin --password 123456
```

### Java Client with Client Certificate

```bash
$ ./interactive-riak-cli.sh -p 10017 --tls --client-cert run/openssl-cluster/riakwriteclient.crt.pem --ca-cert run/openssl-cluster/riakca.ca.crt.pem --username riakwriteclient
```

## Docker Compose Cluster

The Docker Compose cluster uses the same authentication methods as the cluster container, but certificates are located in `run/compose-openssl-node/`. You can connect to any node in the cluster - examples below use node 1 (port 10018 for HTTP, 10017 for Protocol Buffers).

### cURL with Username/Password

**Store data (POST):**
```bash
$ curl -k --cacert run/compose-openssl-node/riakca.ca.crt.pem -uriakadmin:123456 -X POST https://127.0.0.1:10018/buckets/mybucket/keys/mykey -d 'some value'
```

**Retrieve data (GET):**
```bash
$ curl -k --cacert run/compose-openssl-node/riakca.ca.crt.pem -uriakadmin:123456 https://127.0.0.1:10018/buckets/mybucket/keys/mykey
```

### cURL with Client Certificate

**Retrieve data (GET):**
```bash
$ curl -k --cert run/compose-openssl-node/riakwriteclient.crt.pem --key run/compose-openssl-node/riakwriteclient.key.pem --cacert run/compose-openssl-node/riakca.ca.crt.pem https://127.0.0.1:10018/buckets/mybucket/keys/mykey
```

### Java Client with Username/Password

```bash
$ ./interactive-riak-cli.sh -p 10017 --tls --ca-cert run/compose-openssl-node/riakca.ca.crt.pem --username riakadmin --password 123456
```

### Java Client with Client Certificate

```bash
$ ./interactive-riak-cli.sh -p 10017 --tls --client-cert run/compose-openssl-node/riakwriteclient.crt.pem --ca-cert run/compose-openssl-node/riakca.ca.crt.pem --username riakwriteclient
```

## Creating Additional Client Certificates

You can create additional client certificates for custom users using the `request_cert.sh` script. The certificates will be placed in the appropriate directory based on the container type you specify:

- **Cluster container:** `./run/openssl-cluster/`
- **Docker Compose cluster:** `./run/compose-openssl-node/`

**Usage:**
```bash
./run/request_cert.sh <container_type> <username> <group> [<openssl_config_file>]
```

**Parameters:**
- `container_type`: cluster or compose
- `group`: mutable or immutable
- `openssl_config_file`: optional

**Examples:**
```bash
# Create certificate for cluster container
./run/request_cert.sh cluster myuser mutable

# Create certificate for compose cluster
./run/request_cert.sh compose mycomposeuser mutable
```

The generated certificates can be used with the same client examples shown above, just replace `riakwriteclient` with your custom username in the file paths.

## Java Client Installation

The Java client (`interactive-riak-cli`) can be found in your favorite git repository under the name 'interactive-riak-cli'. Download and build it according to the project's instructions to use the Java client examples in this guide.
