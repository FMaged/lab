#!/usr/bin/env bash
# Deletes every secret this deployment left on the host; safe to run twice.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -f "${repo_root}/.env"

# State holds guest passwords unencrypted; .terraform.lock.hcl is a committed pin and stays.
rm -rf "${repo_root}/terraform/.terraform" "${repo_root}"/terraform/terraform.tfstate*
rm -rf "${repo_root}/opnsense/.terraform" "${repo_root}"/opnsense/terraform.tfstate*

rm -f /root/proxmox-api-tokens.txt
rm -f "${repo_root}/proxmox/answer.rendered.toml" "${repo_root}"/proxmox/*.iso

echo "host scrubbed — release the server in the provider's console now."
