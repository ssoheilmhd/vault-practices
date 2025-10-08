Vault Cluster Deployment
This repository contains the necessary configuration files and instructions for deploying a HashiCorp Vault cluster in a test environment.

⚠️ Important Notes
This setup is NOT production-ready and should only be used for testing purposes

The current Docker Compose configuration requires security hardening for production use

Network access should be restricted to only necessary services (nginx)

Docker capabilities may need adjustment based on security requirements

Architecture Overview
The Vault cluster requires:

Three nodes with mutual network access

Nodes within the same broadcast domain (for Keepalived)

VIP (Virtual IP) for cluster leadership

Assumed IP Configuration:
Node1: 10.20.30.1

Node2: 10.20.30.2

Node3: 10.20.30.3

VIP: 10.20.30.123

SSL Configuration
Two types of SSL are used:

Internal Cluster SSL: Automatically handled by Vault for inter-node communication

External Application SSL: Handled by nginx reverse proxy for external connections

Prerequisites
File Permissions
Set proper permissions for the vault user (UID 1000):

bash
chown -R 1000:1000 /var/lib/docker/volumes/new-vault_vault-data-node
Audit Log Access
Ensure proper access to the audit log file:

bash
# Manage permissions for /var/log/new-vault-audit.log
Vault Configuration (node.hcl)
Create config/node.hcl with the following structure:

hcl
# Storage configuration
storage "raft" {
  path    = "/vault/data"
  node_id = "node1"

  retry_join {
    leader_api_addr = "http://10.20.30.123:8200"
    leader_tls_skip_verify = true
  }
}

# Listener configuration with TLS
listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_address  = "0.0.0.0:8201"
  tls_disable      = true
}

# Other settings
api_addr = "http://10.20.30.123:8200"
cluster_addr = "http://10.20.30.1:8201"
disable_mlock = true
ui = true
Configuration Notes
storage section: Uses Raft backend storage

node_id: Must be unique for each node

path: Storage location for secrets, users, policies, and database

retry_join: Points to VIP for cluster joining

listener: Configures cluster (8201) and application (8200) ports

api_addr: Should point to leader address (VIP)

cluster_addr: Unique address for each node's cluster communication

Keepalived Script
Create check_vault_leader.sh for VIP management:

bash
#!/bin/bash

curl -s "http://127.0.0.1:8200/v1/sys/health" | grep -w "standby\"\:false" > /dev/null
this_node_is_leader=$?

if [[ $this_node_is_leader = 0 ]]
then
    exit 0
else
    exit 1
fi
Make executable:

bash
chmod +x check_vault_leader.sh
Cluster Initialization
Step 1: Initialize Leader Node
bash
export VAULT_ADDR=http://127.0.0.1:8200
vault operator init
This outputs:

5 unseal keys (configurable)

1 root token

Store these securely!

Step 2: Unseal Leader Node
bash
vault operator unseal
Step 3: Join and Unseal Other Nodes
For additional nodes:

Only unseal (no initialization needed)

Use the unseal keys from the leader

Step 4: Verify Cluster Status
bash
vault status
Quick Installation
Clone the repository on three VMs:

bash
https://azure.asax.ir/tfs/AsaProjects/ITOperation/_git/vault?path=/vault-deployment&version=GBmain
VM Requirements:
Shared network between VMs

IP addresses configured on ens37 interface:

10.20.30.1

10.20.30.2

10.20.30.3

Setup Steps:
Modify node.hcl for each node (update cluster_addr and node_id)

Copy remaining files as-is

Set permissions:

bash
chown -R 1000:1000 /var/lib/docker/volumes/new-vault_vault-data-node
Make keepalived script executable:

bash
chmod +x check_vault_leader.sh
Initialize and join cluster using the methods described above

References
For more detailed information, refer to:

Storage model comparison document (Section 3.1)

Vault operation monitoring process document

Vault storage model comparison (Section 3.2)

Troubleshooting
Ensure all nodes can communicate on ports 8200 and 8201

Verify VIP is properly assigned to the leader node

Check audit logs for any access issues

Validate nginx SSL configuration for external access

Security Considerations
Restrict network access to vault containers

Review and adjust Docker capabilities

Implement proper SSL certificate management

Secure unseal keys and root tokens

Regular security audits and updates
