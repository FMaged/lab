#!/usr/bin/env bash
# Writes .env from example.env with every locally generatable credential filled
# in. Refuses to touch an existing .env — see the zero-touch decision in PLAN.md.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_env="${repo_root}/example.env"
env_file="${repo_root}/.env"

if [[ -e "${env_file}" ]]; then
  echo "error: ${env_file} already exists — refusing to overwrite it" >&2
  exit 1
fi

# Alphanumeric only, never quotes/backslash/dollar/backtick: this project has
# already been bitten once by an unescaped password reaching a remote-exec
# command line (see FIXES.md). A 32-char mixed-case+digit string clears AD's
# default 3-of-4 complexity rule without needing a symbol at all.
#
# pipefail is off inside these two: `tr` from /dev/urandom never reaches EOF,
# so it always dies of SIGPIPE once `head -c` has read enough — a always-fails
# exit status for a pipeline that otherwise worked exactly as intended, and
# with pipefail on it would trip set -e on the very next `x="$(gen_secret)"`.
gen_secret() {
  set +o pipefail
  LC_ALL=C tr -dc 'A-Za-z0-9' <"/dev/urandom" | head -c "${1:-32}"
}

# sha512crypt's own salt alphabet, per crypt(3).
gen_salt() {
  set +o pipefail
  LC_ALL=C tr -dc './A-Za-z0-9' <"/dev/urandom" | head -c 16
}

set_var() {
  local name="$1" value="$2"
  sed -i "s|^${name}=.*|${name}=${value}|" "${env_file}"
}

(umask 077 && cp "${example_env}" "${env_file}")

# Guest passwords. local_admin_password is deliberately one value shared by
# both tools: Packer bakes it into the templates, Terraform authenticates
# with it.
local_admin_password="$(gen_secret)"
set_var "PKR_VAR_local_admin_password" "${local_admin_password}"
set_var "TF_VAR_local_admin_password" "${local_admin_password}"
set_var "TF_VAR_domain_admin_password" "$(gen_secret)"
set_var "TF_VAR_dsrm_recovery_password" "$(gen_secret)"

# OPNsense root password: config.xml's own <passwd> hash is what actually
# takes effect (PLAN.md), so both the plaintext (for the operator) and its
# sha512crypt hash (for the template) are generated together.
opnsense_root_password="$(gen_secret)"
set_var "PKR_VAR_opnsense_root_password" "${opnsense_root_password}"
set_var "PKR_VAR_opnsense_root_password_hash" \
  "$(openssl passwd -6 -salt "$(gen_salt)" "${opnsense_root_password}")"

# OPNsense API key/secret for opnsense/'s Terraform provider. The key is
# stored in config.xml as plaintext; only the secret is hashed there.
opnsense_api_secret="$(gen_secret)"
set_var "OPNSENSE_API_KEY" "$(gen_secret 40)"
set_var "OPNSENSE_API_SECRET" "${opnsense_api_secret}"
set_var "PKR_VAR_opnsense_api_secret_hash" \
  "$(openssl passwd -6 -salt "$(gen_salt)" "${opnsense_api_secret}")"

# Proxmox endpoint, URI and API tokens are deliberately left as placeholders:
# the endpoint/URI depend on a host that doesn't exist yet, and the two
# tokens are minted by the host's own first-boot hook (task 9), not by this
# script.

echo "wrote ${env_file}"
