#!/usr/bin/env bash
# Writes .env from example.env with every locally generatable credential filled in.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_env="${repo_root}/example.env"
env_file="${repo_root}/.env"

if [[ -e "${env_file}" ]]; then
  echo "error: ${env_file} already exists — refusing to overwrite it" >&2
  exit 1
fi

# Alphanumeric so it survives remote-exec command lines; still meets AD complexity.
# pipefail off: tr always dies of SIGPIPE once head has enough.
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

local_admin_password="$(gen_secret)"
set_var "PKR_VAR_local_admin_password" "${local_admin_password}"
set_var "TF_VAR_local_admin_password" "${local_admin_password}"
set_var "TF_VAR_domain_admin_password" "$(gen_secret)"
set_var "TF_VAR_dsrm_recovery_password" "$(gen_secret)"

# No hash needed: Packer rotates root to this over SSH after the build.
set_var "PKR_VAR_opnsense_root_password" "$(gen_secret)"

# config.xml stores the API key in plaintext but only a hash of the secret.
opnsense_api_secret="$(gen_secret)"
set_var "OPNSENSE_API_KEY" "$(gen_secret 40)"
set_var "OPNSENSE_API_SECRET" "${opnsense_api_secret}"
set_var "PKR_VAR_opnsense_api_secret_hash" \
  "$(openssl passwd -6 -salt "$(gen_salt)" "${opnsense_api_secret}")"

# Plaintext kept for the operator's own login; answer.toml only gets the hash.
proxmox_root_password="$(gen_secret)"
set_var "PROXMOX_ROOT_PASSWORD" "${proxmox_root_password}"
set_var "PROXMOX_ROOT_PASSWORD_HASH" \
  "$(openssl passwd -6 -salt "$(gen_salt)" "${proxmox_root_password}")"

# Proxmox endpoint and API tokens stay placeholders; the host fills them in.

echo "wrote ${env_file}"
