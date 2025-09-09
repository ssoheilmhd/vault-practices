#!/bin/bash

# Configuration
VAULT_ADDR="<address>"
VAULT_TOKEN="<token>"

# Export Vault environment variables
export VAULT_ADDR="$VAULT_ADDR"
export VAULT_TOKEN="$VAULT_TOKEN"

# Create backup directory
BACKUP_DIR="vault_policies_backup_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

echo "Starting Vault policy backup..."
echo "Vault Address: $VAULT_ADDR"
echo "Backup Directory: $BACKUP_DIR"
echo "=========================================="

# Get all policies
echo "Listing all policies..."
vault policy list -tls-skip-verify | while read policy_name; do
    if [ "$policy_name" != "" ] && [ "$policy_name" != "default" ] && [ "$policy_name" != "root" ]; then
        echo "Backing up policy: $policy_name"

        # Read policy content
        vault policy read -tls-skip-verify "$policy_name" > "$BACKUP_DIR/${policy_name}.hcl" 2>/dev/null

        if [ $? -eq 0 ]; then
            echo "✅ Successfully backed up: $policy_name"
        else
            echo "❌ Failed to backup: $policy_name"
        fi
    else
        echo "Skipping system policy: $policy_name"
    fi
done

# Also backup ACL policies (if using older Vault version)
echo "------------------------------------------"
echo "Backing up ACL policies..."
vault policy list -tls-skip-verify | grep -E '^acl/' | while read policy_name; do
    echo "Backing up ACL policy: $policy_name"
    vault policy read -tls-skip-verify "$policy_name" > "$BACKUP_DIR/${policy_name}.hcl" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✅ Successfully backed up: $policy_name"
    else
        echo "❌ Failed to backup: $policy_name"
    fi
done

echo "=========================================="
echo "Policy backup completed! Files saved in: $BACKUP_DIR"
echo "Total policies backed up: $(ls -1 "$BACKUP_DIR"/*.hcl 2>/dev/null | wc -l)"
