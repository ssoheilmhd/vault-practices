# Vault Proxy Stack Documentation

This repository contains a HashiCorp Vault setup with a proxy service and Python client application.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Configuration](#configuration)
- [Usage](#usage)
- [Components](#components)
  - [Vault Server](#vault-server)
  - [Vault Proxy](#vault-proxy)
  - [Python Client](#python-client)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Overview

This project demonstrates a Vault proxy setup that:
- Uses AppRole authentication
- Implements token caching
- Provides a Python client to interact with the proxy
- Includes health checks and retry logic

## Architecture

```
+----------------+       +---------------+       +----------------+
| Python Client  | <---> | Vault Proxy   | <---> | Vault Server   |
+----------------+       +---------------+       +----------------+
```

## Prerequisites

- Docker and Docker Compose
- Python 3.9+ (for local development)
- HashiCorp Vault CLI (optional)

## Setup

1. Clone this repository
2. Update the IP addresses in the configuration files
3. Run the stack:

```bash
docker-compose -f vault-server/compose.yml up -d
docker-compose -f vault-proxy/compose.yml up -d
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VAULT_DEV_ROOT_TOKEN_ID` | Root token for dev server | `root` |
| `VAULT_ADDR` | Vault server address | `http://<Vault-Addr>:<Vault-Port>` |
| `VAULT_PROXY_ADDR` | Vault proxy address | `http://vault-proxy:8100` |
| `VAULT_TOKEN_PATH` | Path to token file | `/tmp/vault_token` |
| `SECRET_PATH` | Path to secrets in Vault | `secret/data/appset` |

## Usage

### Accessing Secrets

The Python client will automatically:
1. Authenticate with the proxy
2. Retrieve the token
3. Fetch secrets from the specified path

Run the client:
```bash
docker-compose -f vault-proxy/compose.yml run python-app python vault_client.py
```

## Components

### Vault Server

- Runs in dev mode
- Exposed on port 8200
- Root token: `root`

**File**: `vault-server/compose.yml`

### Vault Proxy

- Uses AppRole authentication
- Implements token caching
- Exposed on port 8100
- Configuration in `f.hcl`

**Files**:
- `vault-proxy/compose.yml`
- `vault-proxy/f.hcl`
- `vault-proxy/Dockerfile`

### Python Client

- Uses `hvac` library
- Implements retry logic
- Reads token from shared volume

**Files**:
- `vault-proxy/vault_client.py`
- `vault-proxy/requirements.txt`

## Troubleshooting

1. **Connection issues**:
   - Verify IP addresses in config files
   - Check container logs: `docker logs vault-proxy`

2. **Authentication failures**:
   - Verify role_id and secret_id
   - Check token file permissions

3. **Secret not found**:
   - Verify the secret path exists in Vault
   - Check policies for the AppRole

## Security Considerations

⚠️ **This is a development setup - not for production use** ⚠️

- Dev mode Vault server should never be used in production
- Tokens and secrets are exposed in configuration files
- No TLS encryption in this setup
- Root token is hardcoded

For production:
- Enable TLS
- Use proper secrets management
- Implement more restrictive policies
- Use Vault's production mode
