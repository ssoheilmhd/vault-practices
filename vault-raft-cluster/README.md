# Vault Cluster Deployment

This repository contains the necessary configuration files and instructions for deploying a HashiCorp Vault cluster in a test environment.

## ⚠️ Important Notes

- **This setup is NOT production-ready** and should only be used for testing purposes
- The current Docker Compose configuration requires security hardening for production use
- Network access should be restricted to only necessary services (nginx)
- Docker capabilities may need adjustment based on security requirements

## Architecture Overview

The Vault cluster requires:
- Three nodes with mutual network access
- Nodes within the same broadcast domain (for Keepalived)
- VIP (Virtual IP) for cluster leadership

### Assumed IP Configuration:
- Node1: 10.20.30.1
- Node2: 10.20.30.2  
- Node3: 10.20.30.3
- VIP: 10.20.30.123

## Prerequisites

### File Permissions
Set proper permissions for the vault user (UID 1000):
```bash
chown -R 1000:1000 /var/lib/docker/volumes/new-vault_vault-data-node
```

### Audit Log Access
Ensure proper access to the audit log file:
```bash
# Manage permissions for /var/log/new-vault-audit.log
```

## SSL Configuration

Two types of SSL are used:
1. **Internal Cluster SSL**: Automatically handled by Vault for inter-node communication
2. **External Application SSL**: Handled by nginx reverse proxy for external connections

## Configuration Files Explanation

### Docker Compose
The `docker-compose.yml` file sets up:
- Vault node with cluster communication ports (8200, 8201)
- Nginx reverse proxy for SSL termination
- Persistent storage volumes
- Proper user permissions and capabilities

### Vault Configuration (node.hcl)
Each node requires a unique `node.hcl` file with:
- **storage section**: Raft backend configuration with unique node_id
- **retry_join**: Points to VIP for cluster joining
- **listener**: Configures cluster and application ports
- **api_addr**: Leader address (should point to VIP)
- **cluster_addr**: Unique address for each node's cluster communication

### Keepalived Script
The `check_vault_leader.sh` script manages VIP assignment by checking if the current node is the cluster leader.

Make executable:
```bash
chmod +x check_vault_leader.sh
```

## Cluster Initialization

### Step 1: Initialize Leader Node
```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault operator init
```

This outputs:
- 5 unseal keys (configurable)
- 1 root token

**Store these securely!**

### Step 2: Unseal Leader Node
```bash
vault operator unseal
```

### Step 3: Join and Unseal Other Nodes
For additional nodes:
- Only unseal (no initialization needed)
- Use the unseal keys from the leader

### Step 4: Verify Cluster Status
```bash
vault status
```

## Quick Installation

### VM Requirements:
- Shared network between three VMs
- IP addresses configured on ens37 interface:
  - 10.20.30.1
  - 10.20.30.2  
  - 10.20.30.3

### Setup Steps:
1. Clone this repository on all three VMs
2. Modify `node.hcl` for each node (update `cluster_addr` and `node_id`)
3. Set proper permissions:
   ```bash
   chown -R 1000:1000 /var/lib/docker/volumes/new-vault_vault-data-node
   ```
4. Make keepalived script executable:
   ```bash
   chmod +x check_vault_leader.sh
   ```
5. Start the services using Docker Compose
6. Initialize and join cluster using the methods described above

## Important Configuration Notes

- **node_id**: Must be unique for each Vault node in the cluster
- **retry_join**: Should use VIP address to ensure proper cluster joining
- **cluster_addr**: Each node needs its own unique IP address for cluster communication
- **api_addr**: Should point to the VIP address for proper leader routing
- VIP management is handled through Keepalived with the provided health check script

## Troubleshooting

- Ensure all nodes can communicate on ports 8200 and 8201
- Verify VIP is properly assigned to the leader node
- Check that each node has unique node_id and cluster_addr values
- Validate nginx SSL configuration for external access
- Confirm proper file permissions for vault user (UID 1000)

## Security Considerations

- Restrict network access to vault containers
- Review and adjust Docker capabilities as needed
- Implement proper SSL certificate management for nginx
- Secure unseal keys and root tokens in a safe location
- Regular security audits and updates recommended
