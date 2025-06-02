#!/bin/bash

VAULT_PREFIX="ats/"
declare -A VAULT_URLS=(
    ["asiatech"]="https://<asiatech-url>"
    ["shatel"]="https://<shatel-url>/"
)
VAULT_USERNAME="ats-admin"
VAULT_SKIP_VERIFY="true"

login_to_dc() {
    local dc_name="$1"
    if [[ -z "${VAULT_URLS[$dc_name]}" ]]; then
        echo "Error: Unknown data center '$dc_name'"
        echo "Available options: ${!VAULT_URLS[@]}"
        exit 1
    fi

    export VAULT_ADDR="${VAULT_URLS[$dc_name]}"
    export VAULT_SKIP_VERIFY="$VAULT_SKIP_VERIFY"
    vault login -method=userpass username="$VAULT_USERNAME"
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [asiatech|shatel]"
    echo "Available data centers: ${!VAULT_URLS[@]}"
    exit 1
fi

login_to_dc "$1"

list_paths() {
    local current_path="$1"
    local full_path="$VAULT_PREFIX$current_path"
    entries=`vault kv list $full_path`
    if [[ -n "$entries" ]]; then
        for entry in $entries; do
            if [[ "$entry" != "." && "$entry" != ".." ]]; then
                new_path="$current_path$entry"
                list_paths "$new_path/"
            fi
        done
    fi
}

list_paths ""
