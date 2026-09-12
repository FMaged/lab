#!/usr/bin/env bash
# Renders proxmox/answer.toml from .env, then embeds it and the first-boot
# hook into a prepared installer ISO with proxmox-auto-install-assistant.
# Both the rendered answer file and the prepared ISO are gitignored — see the
# zero-touch decision in PLAN.md. Needs proxmox-auto-install-assistant, which
# this repo has no way to install or run — there is no host to prove this
# against yet (see AGENTS.md).
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <path-to-proxmox-ve-iso> <output-iso-path>" >&2
  exit 1
fi
source_iso="$1"
output_iso="$2"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${PROXMOX_ROOT_PASSWORD_HASH:-}" ]]; then
  echo "error: PROXMOX_ROOT_PASSWORD_HASH is not set — run 'set -a; . ./.env; set +a' first" >&2
  exit 1
fi

rendered="${repo_root}/proxmox/answer.rendered.toml"
(umask 077 && sed "s|\${PROXMOX_ROOT_PASSWORD_HASH}|${PROXMOX_ROOT_PASSWORD_HASH}|" \
  "${repo_root}/proxmox/answer.toml" >"${rendered}")

proxmox-auto-install-assistant prepare-iso "${source_iso}" \
  --fetch-from iso \
  --answer-file "${rendered}" \
  --on-first-boot "${repo_root}/proxmox/first-boot-hook.sh" \
  --output "${output_iso}"

echo "prepared ${output_iso}"
