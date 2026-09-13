#!/usr/bin/env bash
# Removes every secret this deployment leaves on the host: .env, both
# Terraform roots' state (whose connection blocks put the guest passwords in
# it — Terraform marks them sensitive for display, but the state file itself
# is not encrypted at rest), the first-boot hook's token file if it's still
# there, and any rendered Proxmox answer file or prepared installer ISO.
# Runs on the host itself, on its own — nothing to lose by running it twice
# (task 10, PLAN.md). Releasing the rented server by hand does not guarantee
# the provider wipes its disks, so this runs before that happens, not instead
# of it.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -f "${repo_root}/.env"

# .terraform.lock.hcl stays — it is a committed provider pin, not a secret.
rm -rf "${repo_root}/terraform/.terraform" "${repo_root}"/terraform/terraform.tfstate*
rm -rf "${repo_root}/opnsense/.terraform" "${repo_root}"/opnsense/terraform.tfstate*

rm -f /root/proxmox-api-tokens.txt
rm -f "${repo_root}/proxmox/answer.rendered.toml" "${repo_root}"/proxmox/*.iso

echo "host scrubbed — release the server in the provider's console now."
