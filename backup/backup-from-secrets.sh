#!/bin/bash

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

BACKUP_DIR="vault_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Get all secret mounts
vault secrets list -tls-skip-verify -format=json | jq -r 'keys[]' | while read mount; do
    echo "Processing mount: $mount"
    echo "------------------------------------------"

    # Process each mount recursively
    process_secrets "$mount" "$BACKUP_DIR"
done

echo "=========================================="
echo "Backup completed! Files saved in: $BACKUP_DIR"
