#!/bin/bash

# Configuration
VAULT_ADDR="<address>"
VAULT_TOKEN="<token>"
BACKUP_DIR="<DIR_NAME_FOR_BACKUP_WHICH_YOU_HAVE_IT_FROM_BACKUP_SCRIPT>"  # Change this to your backup directory

# Export Vault environment variables
export VAULT_ADDR="$VAULT_ADDR"
export VAULT_TOKEN="$VAULT_TOKEN"

# Function to restore secrets from JSON files
restore_secrets() {
    local file_path="$1"
    local vault_path="$2"

    echo "Restoring: $vault_path"
    echo "From file: $file_path"

    # Check if the vault path is valid (not empty)
    if [ -n "$vault_path" ]; then
        # Create a temporary file with proper KV v2 structure
        local temp_file=$(mktemp)

        # Wrap the data in the proper KV v2 structure
        echo '{"data":' > "$temp_file"
        cat "$file_path" >> "$temp_file"
        echo '}' >> "$temp_file"

        # Use vault kv put to restore the secret with explicit path
        if vault kv put -tls-skip-verify "$vault_path" @"$temp_file"; then
            echo "✅ Successfully restored: $vault_path"
            rm -f "$temp_file"
            return 0
        else
            echo "❌ Failed to restore: $vault_path"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo "❌ Invalid vault path"
        return 1
    fi
}

# Function to check if KV v2 engine exists, create if not
ensure_kv_engine() {
    local engine_name="$1"

    echo "Checking if KV v2 engine '$engine_name' exists..."

    if vault secrets list -tls-skip-verify | grep -q "^${engine_name}/"; then
        echo "✅ KV engine '$engine_name' already exists"
    else
        echo "Creating KV v2 engine '$engine_name'..."
        if vault secrets enable -tls-skip-verify -path="$engine_name" -version=2 kv; then
            echo "✅ Successfully created KV v2 engine: $engine_name"
        else
            echo "❌ Failed to create KV v2 engine: $engine_name"
            exit 1
        fi
    fi
}

# Function to recursively process backup directory
process_backup_directory() {
    local current_dir="$1"
    local current_vault_path="$2"

    # Process all files and directories in the current backup directory
    for item in "$current_dir"/*; do
        if [ -f "$item" ]; then
            # This is a secret file
            local secret_name=$(basename "$item" .json)
            local full_vault_path="${current_vault_path}/${secret_name}"
            restore_secrets "$item" "$full_vault_path"

        elif [ -d "$item" ]; then
            # This is a subdirectory, recurse into it
            local dir_name=$(basename "$item")
            local new_vault_path="${current_vault_path}/${dir_name}"
            process_backup_directory "$item" "$new_vault_path"
        fi
    done
}

# Main execution
echo "Starting Vault secret restore..."
echo "Vault Address: $VAULT_ADDR"
echo "Backup Directory: $BACKUP_DIR"
echo "=========================================="

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup directory '$BACKUP_DIR' not found!"
    exit 1
fi

# Process each top-level directory (secret engine)
for engine_dir in "$BACKUP_DIR"/*; do
    if [ -d "$engine_dir" ]; then
        engine_name=$(basename "$engine_dir")
        echo "=========================================="
        echo "Processing engine: $engine_name"
        echo "=========================================="

        # Ensure the KV v2 engine exists
        ensure_kv_engine "$engine_name"

        # Process all secrets under this engine
        process_backup_directory "$engine_dir" "$engine_name"
    fi
done

echo "=========================================="
echo "Restore completed!"
