#!/bin/bash
export VAULT_ADDR="https://vault-addr"
export VAULT_TOKEN="vault token"
# Configuration
BACKUP_DIR="vault_backup_from_keys"  # Change this to your backup directory

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
        cat "$file_path" > "$temp_file"

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
#!/bin/bash

# Configuration

BACKUP_DIR="vault_backup_from_policies"  # Change this to your backup directory

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


#!/bin/bash

# Vault UserPass Creation Script
# Usage: ./vault-userpass-setup.sh <input_file.json>

set -e  # Exit on any error
vault  auth enable -tls-skip-verify userpass
# Configuration
USERPASS_MOUNT="${USERPASS_MOUNT:-userpass}"

# Function to display usage
usage() {
    echo "Usage: $0 <input_file.json>"
    echo "The JSON file should contain key-value pairs where:"
    echo "  key = username"
    echo "  value = password"
    echo ""
    echo "Example JSON format:"
    echo '{
  "ams-admin": "RWY45LL5n4cW4K",
  "amsdev": "6C£n2R5T?x2( ",
  "tmsadmin": "9q5st5sb0ScQw/1U7+K3cPzubGgUz/n2crLPWD8PXEI=",
  "tmsdev": "XdEb1TxstAYeem4/0iWTVmd1OFiwavVdufs/sKMhO58="
}'
    exit 1
}

# Function to check if Vault is reachable
check_vault() {
    if ! vault status -tls-skip-verify >/dev/null 2>&1; then
        echo "Error: Cannot connect to Vault at $VAULT_ADDR"
        echo "Please ensure:"
        echo "1. Vault server is running"
        echo "2. VAULT_ADDR is set correctly"
        echo "3. You are authenticated (vault login)"
        exit 1
    fi
}

# Function to check if userpass auth method is enabled
check_userpass_mount() {
    if ! vault auth list -tls-skip-verify | grep -q "^$USERPASS_MOUNT/"; then
        echo "Error: Userpass auth method not enabled at path '$USERPASS_MOUNT'"
        echo "To enable it, run: vault auth enable -path=$USERPASS_MOUNT userpass"
        exit 1
    fi
}

# Function to create user in userpass
create_user() {
    local username="$1"
    local password="$2"

    echo "Creating user: $username"

    # Create the user with the specified password
    if vault write -tls-skip-verify "auth/$USERPASS_MOUNT/users/$username" \
        password="$password"  >/dev/null 2>&1; then
        return 0
    else
        echo "✗ Failed to create user: $username"
        return 1
    fi
}

# Main script execution
main() {
    # Check if input file is provided

    local input_file="user.json"

    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        echo "Error: Input file '$input_file' not found"
        exit 1
    fi

    # Validate JSON format
    if ! jq empty "$input_file" 2>/dev/null; then
        echo "Error: Invalid JSON format in '$input_file'"
        exit 1
    fi

    # Check Vault connection and auth method
    echo "Checking Vault connection..."
    check_vault
    check_userpass_mount

    echo "Starting user creation process..."
    echo "================================="

    # Count variables
    success_count=0
    error_count=0

    # Temporary file to store results
    temp_file=$(mktemp)

    # Read JSON file and create users - using process substitution to avoid subshell
    while IFS=" " read -r username password; do
        if [ -n "$username" ] && [ -n "$password" ]; then
            if create_user "$username" "$password"; then
                echo "success" >> "$temp_file"
            else
                echo "error" >> "$temp_file"
            fi
        fi
    done < <(jq -r 'to_entries[] | "\(.key) \(.value)"' "$input_file")

    # Count results from temporary file
    success_count=$(grep -c "success" "$temp_file" || true)
    error_count=$(grep -c "error" "$temp_file" || true)

    # Clean up temp file
    rm -f "$temp_file"

    echo "================================="
    echo "User creation completed:"
    echo "Successful: $success_count"
    echo "Failed: $error_count"

    if [ $error_count -eq 0 ]; then
        echo "All users created successfully!"
    else
        echo "Some users failed to create. Check the errors above."
        exit 1
    fi
}

# Run main function with all arguments
main "$@"




#!/bin/bash

# Simple Vault UserPass Policy Update Script for your format
# Usage: ./fix-user-policies.sh <backup_file.json>

set -e

USERPASS_MOUNT="${USERPASS_MOUNT:-userpass}"

usage() {
    echo "Usage: $0 <backup_file.json>"
    echo "Backup file should contain users with token_policies array"
    exit 1
}

check_vault() {
    if ! vault status -tls-skip-verify >/dev/null 2>&1; then
        echo "Error: Cannot connect to Vault. Make sure you're logged in."
        exit 1
    fi
}

update_policies() {
    local backup_file="vault-userBindpolicy-backup.json"

    echo "Reading users from: $backup_file"
    echo "================================="

    # Get all usernames
    usernames=$(jq -r 'keys[]' "$backup_file")

    while IFS= read -r username; do
        if [ -z "$username" ]; then
            continue
        fi

        echo "Processing: $username"

        # Extract policies array and convert to comma-separated string
        policies=$(jq -r --arg user "$username" '.[$user].token_policies | join(",")' "$backup_file")

        if [ "$policies" = "null" ] || [ -z "$policies" ]; then
            echo "  No policies found, skipping..."
            continue
        fi

        echo "  Policies: $policies"

        # Update the user
        if vault write -tls-skip-verify "auth/$USERPASS_MOUNT/users/$username" policies="$policies" >/dev/null 2>&1; then
            echo "  ✅ Success"
        else
            echo "  ❌ Failed"
        fi
        echo ""

    done <<< "$usernames"
}

main() {


    local backup_file="vault-userBindpolicy-backup.json"

    if [ ! -f "$backup_file" ]; then
        echo "Error: File not found: $backup_file"
        exit 1
    fi

    if ! jq empty "$backup_file" 2>/dev/null; then
        echo "Error: Invalid JSON file"
        exit 1
    fi

    check_vault
    update_policies "$backup_file"

    echo "================================="
    echo "Policy update completed!"
}

main "$@"
