#!/usr/bin/env bash
# The one command: copies this repository to a rented, freshly-installed
# Proxmox host over SSH and runs scripts/host-runner.sh there — see the
# decision in PLAN.md on why the build runs on the host, not here. The
# operator needs SSH and nothing else: no Terraform, no Packer, no route
# into the lab's own VLANs.
#
# Usage: scripts/deploy.sh <host-address>
#
# shellcheck disable=SC2029 # every remote command below is built by
# substituting local variables into the string before ssh ever sends it —
# there is no remote-side variable of the same name to collide with.
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

# Everything git tracks, plus .env (gitignored on purpose — the secrets
# decision in PLAN.md) and any *.auto.tfvars / *.auto.pkrvars.hcl a layer's
# own README asks the operator to create locally (also gitignored, but not
# secret — node names, ISO URLs and checksums genuinely have to reach the
# host, or packer/terraform.auto.tfvars-consuming builds would run entirely
# on placeholder defaults). Never .git itself or any .terraform/ cache.
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

# Owner-only, on the host, for everything this copied — not just .env — since
# the destination directory is otherwise created with whatever umask the
# remote shell happened to have.
ssh "root@${host}" "chmod -R go-rwx '${remote_dir}'"

log "running the host-side runner"
ssh "root@${host}" "'${remote_dir}/scripts/host-runner.sh'"
