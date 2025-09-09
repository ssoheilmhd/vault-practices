#!/bin/bash

# Configuration
VAULT_ADDR="<address>"
VAULT_TOKEN="<token>"
BACKUP_DIR="vault_policies_backup_20250909"  # Change this to your backup directory

# Export Vault environment variables
export VAULT_ADDR="$VAULT_ADDR"
export VAULT_TOKEN="$VAULT_TOKEN"

# Function to restore a single policy
restore_policy() {
    local policy_file="$1"
    local policy_name=$(basename "$policy_file" .hcl)

    echo "Restoring policy: $policy_name"
    echo "From file: $policy_file"

    # Check if policy already exists
    if vault policy read -tls-skip-verify "$policy_name" >/dev/null 2>&1; then
        echo "⚠️  Policy already exists: $policy_name"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping policy: $policy_name"
            return 1
        fi
    fi

    # Restore the policy
    if vault policy write -tls-skip-verify "$policy_name" "$policy_file"; then
        echo "✅ Successfully restored: $policy_name"
        return 0
    else
        echo "❌ Failed to restore: $policy_name"
        return 1
    fi
}

# Main execution
echo "Starting Vault policy restore..."
echo "Vault Address: $VAULT_ADDR"
echo "Backup Directory: $BACKUP_DIR"
echo "=========================================="

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory '$BACKUP_DIR' not found!"
    exit 1
fi

# Check if any policy files exist
if ls "$BACKUP_DIR"/*.hcl 1> /dev/null 2>&1; then
    # Process all policy HCL files
    for policy_file in "$BACKUP_DIR"/*.hcl; do
        echo "------------------------------------------"
        restore_policy "$policy_file"
    done
else
    echo "No policy files found (*.hcl)"
    echo "Please run this script in the directory containing the backup files"
    exit 1
fi

echo "=========================================="
echo "Policy restore completed!"
echo "Total policies restored: $(ls -1 "$BACKUP_DIR"/*.hcl 2>/dev/null | wc -l)"
