#!/bin/bash
export VAULT_ADDR="https://vault-addr"
export VAULT_TOKEN="vault token"
# Function to recursively list and process secrets
process_secrets() {
    local current_path="$1"
    local output_dir="${2:-backup}"
    echo "Processing path: $current_path"

    # Create directory structure
    local dir_path="$output_dir/$(echo "$current_path" | sed 's/^\/\?//')"
    mkdir -p "$dir_path"

    # List all items in the current path
    vault kv list -tls-skip-verify -format=json "$current_path" 2>/dev/null | jq -r '.[]' | while read item; do
        if [ "$item" != "" ] && [ "$item" != "null" ]; then
            local full_item_path="${current_path}${item}"

            if [[ "$item" == */ ]]; then
                # This is a directory, recurse into it
                echo "Entering directory: $full_item_path"
                process_secrets "$full_item_path" "$output_dir"
            else
                # This is a secret, read it
                echo "Secret found: $full_item_path"
                local safe_filename="$(echo "$item" | tr '/' '_')"
                vault kv get -tls-skip-verify -format=json "$full_item_path" 2>/dev/null | jq '.data.data' > "$dir_path/$safe_filename.json"
            fi
        fi
    done
}

# Main execution
echo "Starting Vault secret backup..."
echo "=========================================="

BACKUP_DIR="vault_backup_from_keys"
mkdir -p $BACKUP_DIR

# Get all secret mounts
vault secrets list -tls-skip-verify -format=json | jq -r 'keys[]' | while read mount; do
    echo "Processing mount: $mount"
    echo "------------------------------------------"

    # Process each mount recursively
    process_secrets "$mount" "$BACKUP_DIR"
done

echo "=========================================="
echo "Backup completed! Files saved in: $BACKUP_DIR"
#!/bin/bash

# Create backup directory
BACKUP_DIR="vault_backup_from_policies"
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
#!/bin/bash

# Quick Vault UserPass Backup Script
# Usage: ./vault-userpass-quick-backup.sh

set -e

USERPASS_MOUNT="${USERPASS_MOUNT:-userpass}"
BACKUP_FILE="vault-userBindpolicy-backup.json"

check_vault() {
    vault status -tls-skip-verify >/dev/null 2>&1 || {
        echo "Error: Cannot connect to Vault"
        exit 1
    }
}

backup_users() {
    echo "Backing up userpass users to: $BACKUP_FILE"

    # Get all users
    users=$(vault list -tls-skip-verify -format=json "auth/$USERPASS_MOUNT/users" | jq -r '.[]' 2>/dev/null || echo "")

    if [ -z "$users" ]; then
        echo "No users found"
        echo "{}" > "$BACKUP_FILE"
        return 0
    fi

    # Create backup object
    backup_data="{}"

    while IFS= read -r username; do
        if [ -n "$username" ]; then
            echo "Backing up user: $username"
            user_data=$(vault read -tls-skip-verify -format=json "auth/$USERPASS_MOUNT/users/$username" 2>/dev/null || echo "{}")
            backup_data=$(echo "$backup_data" | jq --arg user "$username" --argjson data "$user_data" \
                '. + {($user): $data.data}')
        fi
    done <<< "$users"

    echo "$backup_data" | jq '.' > "$BACKUP_FILE"
    echo "Backup completed: $BACKUP_FILE"

    # Show summary
    user_count=$(echo "$users" | wc -l)
    echo "Users backed up: $user_count"
}

main() {
    check_vault
    backup_users
}

main "$@"
