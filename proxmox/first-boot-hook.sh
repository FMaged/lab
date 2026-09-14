#!/bin/bash
# Runs once via answer.toml's [first-boot]; the proxmox-first-boot package prevents a second run.
# Mints one API token per tool so either can be revoked without touching the other, and writes them
# to a root-only file rather than sending them anywhere — the operator fetches them over SSH.
set -euo pipefail

output_file="/root/proxmox-api-tokens.txt"
umask 077

mint_token() {
  pvesh create "/access/users/root@pam/token/$1" --privsep 0 --output-format json \
    | grep -oP '"value"\s*:\s*"\K[^"]+'
}

{
  echo "# Minted $(date -u +%FT%TZ) by proxmox/first-boot-hook.sh."
  echo "# Copy both lines into .env, then delete this file."
  echo "PROXMOX_VE_API_TOKEN=root@pam!terraform=$(mint_token terraform)"
  echo "PKR_VAR_proxmox_api_token_secret=$(mint_token packer)"
} >"${output_file}"

echo "API tokens minted — see ${output_file}"
