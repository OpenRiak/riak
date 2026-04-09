# Riak Development Environment Setup

This directory contains scripts for generating local development environments for Riak, including support for TLS-enabled configurations.

## Overview

The scripts in this directory help you create multi-node development clusters on your local machine. You can set up either standard HTTP clusters or TLS/HTTPS clusters with certificate-based authentication.

## Scripts Reference

### gen_dev

**Purpose**: Generates configuration for a standard HTTP development node.

**Usage**:
```bash
./gen_dev <node_name> <template_file> <output_vars_file>
```

**Example**:
```bash
./gen_dev dev4 vars/dev_vars.config.src vars/4_vars.config
```

**What it does**:
- Creates node configuration with HTTP endpoints
- Assigns unique ports based on node number

**Port calculation**: For `devN`, base port = `10000 + (10 * N)`
- Cluster Manager: base + 6
- Protocol Buffer: base + 7
- Web/HTTP: base + 8

### gen_tls_dev

**Purpose**: Generates configuration for a TLS-enabled development node.

**Usage**:
```bash
./gen_tls_dev <node_name> <template_file> <output_vars_file>
```

**Example**:
```bash
./gen_tls_dev dev4 vars/dev_vars.config.src vars/4_vars.config
```

**What it does**:
- Creates node configuration with HTTPS endpoints
- Assigns unique ports (same scheme as `gen_dev`)
- Sets `@DIST_TLS_ENABLED@` to `true`
- Configures paths for TLS certificates (cert and CA cert)
- **Note**: This only sets up the configuration; use `gen_tls_devcerts` to create the actual certificates

### gen_tls_devcerts

**Purpose**: Generates TLS certificates for a specific development node and reconfigures it for HTTPS.

**Usage**:
```bash
./gen_tls_devcerts <node_name>
```

**Example**:
```bash
./gen_tls_devcerts dev4
```

**What it does**:
1. Creates a Certificate Authority (CA) if none exists in `dev/ca/`
2. Generates a Certificate Signing Request (CSR) for the node
3. Issues a certificate signed by the CA
4. Creates combined PEM files containing both certificate and key
5. Copies CA certificate to node's `etc/` directory
6. Reconfigures `riak.conf` to:
   - Change HTTP listener to HTTPS
   - Configure SSL certificate paths
   - Configure handoff SSL settings
   - Disable CRL checking

**Generated files**:
- `dev/ca/riakca.pem` - Combined CA certificate and key (shared by all nodes)
- `dev/<node>/riak/etc/<node>.pem` - Combined node certificate and key
- `dev/<node>/riak/etc/<node>.key.pem` - Node private key
- `dev/<node>/riak/etc/<node>.crt.pem` - Node certificate
- `dev/<node>/riak/etc/ca.pem` - CA certificate (copy)

**Prerequisites**:
- Node must already be created
- OpenSSL must be installed

### gen_tls_clientcert

**Purpose**: Generates TLS client certificates for testing certificate-based authentication.

**Usage**:
```bash
./gen_tls_clientcert [client_name]
```

**Examples**:
```bash
./gen_tls_clientcert              # Creates certificate for 'riakuser' (default)
./gen_tls_clientcert testuser     # Creates certificate for 'testuser'
```

**What it does**:
1. Creates a CA if none exists (same CA as node certificates)
2. Generates a CSR for the client
3. Issues a client certificate signed by the CA
4. Stores certificates in `dev/client/`

**Generated files**:
- `dev/ca/riakca.pem` - CA certificate and key (created if needed)
- `dev/client/<name>.key.pem` - Client private key
- `dev/client/<name>.crt.pem` - Client certificate

**Use case**: 
Testing certificate-based authentication. The common name (CN) in the certificate can be used as the username for Riak security.

## Supporting Scripts

### Certificate Generation Tools

Located in `security/bin/`, these are the underlying utilities used by the TLS generation scripts:

#### ca
Creates a Certificate Authority for signing certificates.

**Usage**:
```bash
./security/bin/ca -n <name> -o <output_dir>
```

**Environment variables**:
- `CA_OPENSSL` - OpenSSL binary location (default: `openssl`)
- `CA_CONFIG_FILE` - OpenSSL config file (default: `security/etc/openssl.config`)
- `CA_DAYS` - Certificate validity in days (default: `3650` = 10 years)
- `CA_KEY_SIZE` - Key size in bits (default: `4096`)

#### issue_csr
Creates a Certificate Signing Request.

**Usage**:
```bash
./security/bin/issue_csr -n <common_name> -f <filename> -o <output_dir>
```

**Environment variables**:
- `OPENSSL` - OpenSSL binary location (default: `openssl`)
- `CONFIG_FILE` - OpenSSL config file (default: `security/etc/openssl.config`)
- `KEY_SIZE` - Key size in bits (default: `4096`)

#### issue_cert
Issues a certificate from a CSR using a CA.

**Usage**:
```bash
./security/bin/issue_cert -r <csr_file> -c <ca_cert> -k <ca_key> -o <output_dir>
```

**Environment variables**:
- `CA_OPENSSL` - OpenSSL binary location (default: `openssl`)
- `CA_DAYS` - Certificate validity in days (default: `3650` = 10 years)

## Configuration Template

The scripts use a template file (`vars/dev_vars.config.src`) that contains placeholders:
- `@NODE@` - Node name (e.g., `dev1@127.0.0.1`)
- `@PBPORT@` - Protocol Buffer port
- `@WEBPORT@` - HTTP/HTTPS port
- `@CM_PORT@` - Cluster Manager port
- `@HANDOFFPORT@` - Handoff port
- `@DIST_TLS_ENABLED@` - Whether inter-node TLS is enabled
- `@DIST_TLS_CERTFILE@` - Path to node certificate
- `@DIST_TLS_CACERTFILE@` - Path to CA certificate
- `@PLATFORM_BASE_DIR@` - Base directory for the node

## Directory Structure After Setup

```
dev/
├── ca/
│   ├── riakca.ca.key.pem      # CA private key
│   ├── riakca.ca.crt.pem      # CA certificate
│   └── riakca.pem             # Combined CA cert + key
├── client/
│   ├── riakuser.key.pem       # Client private key
│   └── riakuser.crt.pem       # Client certificate
├── dev1/
│   └── riak/
│       ├── bin/               # Executables (riak, riak-admin)
│       ├── etc/               # Configuration files
│       │   ├── riak.conf
│       │   ├── dev1.pem       # Node cert + key (TLS only)
│       │   ├── dev1.key.pem   # Node private key (TLS only)
│       │   ├── dev1.crt.pem   # Node certificate (TLS only)
│       │   └── ca.pem         # CA certificate (TLS only)
│       ├── data/              # Database files
│       └── log/               # Log files
├── dev2/
│   └── riak/...
└── dev3/
    └── riak/...
```
