#!/usr/bin/env bash
# Copies the repo to a fresh Proxmox host and runs scripts/host-runner.sh there.
# Usage: scripts/deploy.sh <host-address>
# shellcheck disable=SC2029 # remote commands are expanded locally on purpose
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <host-address>" >&2
  exit 1
fi
host="$1"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
remote_dir="/root/silab"

if [[ ! -f "${repo_root}/.env" ]]; then
  echo "error: .env not found — run scripts/init-env.sh first" >&2
  exit 1
fi

# Tracked files plus the gitignored .env and *.auto.* var files the host needs.
manifest="$(mktemp)"
trap 'rm -f "${manifest}"' EXIT

(
  cd "${repo_root}"
  git ls-files -z
  find . \
    \( -name '*.auto.tfvars' -o -name '*.auto.tfvars.json' \
    -o -name '*.auto.pkrvars.hcl' -o -name '*.auto.pkrvars.hcl.json' \) \
    -not -path './.terraform/*' -print0
  printf '%s\0' .env
) >"${manifest}"

log() {
  echo "==> $*"
}

log "copying the repository to ${host}:${remote_dir}"
ssh "root@${host}" "mkdir -p '${remote_dir}'"
tar -cz -C "${repo_root}" --null -T "${manifest}" |
  ssh "root@${host}" "tar -xz -C '${remote_dir}'"

# The remote umask is unknown, so lock down everything copied, not just .env.
ssh "root@${host}" "chmod -R go-rwx '${remote_dir}'"

log "running the host-side runner"
status=0
ssh "root@${host}" "'${remote_dir}/scripts/host-runner.sh'" || status=$?

if [[ "${status}" -eq 0 ]]; then
  exit 0
fi

echo "error: the run failed — see the runner's own output above." >&2
echo "Before releasing the server, scrub its secrets with:" >&2
echo "  ssh root@${host} '${remote_dir}/scripts/scrub-host.sh'" >&2
exit "${status}"
