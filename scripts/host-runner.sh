#!/usr/bin/env bash
# Runs on the Proxmox host itself, once scripts/deploy.sh has copied the repo
# and .env there (Milestone 10 decision 38 — the build lives on the host, not
# the operator's machine, because Packer's and Terraform's WinRM connections
# have no jump-host option). Takes the host from freshly installed to three
# built templates and four applied guests, in runbook order (sections 2-5),
# skipping any stage whose result already exists — a failure partway through
# must never mean renting a clean host to try again.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: run as root" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${repo_root}/.env"
tools_dir="/opt/silab-tools"
# Exact versions AGENTS.md pins — bumping either is a deliberate, separate
# commit there, never a silent drift here.
terraform_version="1.16.1"
packer_version="1.16.0"

if [[ ! -f "${env_file}" ]]; then
  echo "error: ${env_file} not found — copy .env to the host first (scripts/deploy.sh)" >&2
  exit 1
fi
set -a
# shellcheck source=/dev/null
. "${env_file}"
set +a

log() {
  echo "==> $*"
}

# -- Stage: trust the host's own API certificate ---------------------------
# Packer's sources and Terraform's provider both set insecure_skip_tls_verify
# = false / PROXMOX_VE_INSECURE=false — this is what keeps that honest,
# instead of quietly disabling verification to make the connection work
# (host-network SPIKE, PLAN.md).
stage_trust_proxmox_ca() {
  log "trusting pve-root-ca"
  if [[ ! -f /usr/local/share/ca-certificates/pve-root-ca.crt ]]; then
    cp /etc/pve/pve-root-ca.pem /usr/local/share/ca-certificates/pve-root-ca.crt
    update-ca-certificates
  fi
  # proxmox/answer.toml's own fqdn — fixed regardless of which server is
  # rented, so no substitution needed, only a local resolution for it since
  # no DNS server exists yet at this point.
  if ! grep -qF "pve.silab.internal" /etc/hosts; then
    echo "127.0.0.1 pve.silab.internal" >>/etc/hosts
  fi
}

# -- Stage: install pinned Terraform and Packer ----------------------------
# Downloaded and verified against HashiCorp's own signed checksums, not from
# a package repository — see AGENTS.md's pinning rule and the exact command
# HashiCorp itself documents for this (developer.hashicorp.com/well-
# architected-framework/verify-hashicorp-binary).
install_hashicorp_tool() {
  local name="$1" version="$2"
  local bin="${tools_dir}/${name}"

  if [[ -x "${bin}" ]] && "${bin}" version 2>/dev/null | head -1 | grep -qF "${version}"; then
    log "${name} ${version} already installed"
    return
  fi

  log "installing ${name} ${version}"
  # Left behind on a failed download/verify rather than trapped and cleaned
  # up — bash's RETURN trap fires again on every enclosing function's own
  # return too, not just this one, which is worse than a stray /tmp
  # directory. The host itself is scrubbed or destroyed at the end of the
  # run either way (task 10).
  local work
  work="$(mktemp -d)"

  local base="https://releases.hashicorp.com/${name}/${version}"
  local zip="${name}_${version}_linux_amd64.zip"
  curl -fsSL -o "${work}/${zip}" "${base}/${zip}"
  curl -fsSL -o "${work}/SHA256SUMS" "${base}/${name}_${version}_SHA256SUMS"
  curl -fsSL -o "${work}/SHA256SUMS.sig" "${base}/${name}_${version}_SHA256SUMS.sig"
  curl -fsSL "https://www.hashicorp.com/.well-known/pgp-key.txt" | gpg --import --quiet
  gpg --verify "${work}/SHA256SUMS.sig" "${work}/SHA256SUMS"
  (cd "${work}" && sha256sum -c --ignore-missing SHA256SUMS)

  mkdir -p "${tools_dir}"
  unzip -o -d "${tools_dir}" "${work}/${zip}" "${name}"
  rm -rf "${work}"
}

stage_install_tools() {
  install_hashicorp_tool terraform "${terraform_version}"
  install_hashicorp_tool packer "${packer_version}"
  export PATH="${tools_dir}:${PATH}"
}

# -- Stage: host networking -------------------------------------------------
# vmbr1 (the VLAN 10/20/30 trunk) and vmbr2 (a disposable network Packer
# builds on, since OPNsense doesn't exist yet to route anything) — created
# here, not proxmox/first-boot-hook.sh, so the same script works whether
# Proxmox came from the prepared ISO or a provider's own catalog image (host-
# network SPIKE, PLAN.md).
stage_setup_networks() {
  log "configuring vmbr1 (VLAN trunk) and vmbr2 (build network)"
  local changed=0

  if ! grep -q "^iface vmbr1 " /etc/network/interfaces; then
    cat >>/etc/network/interfaces <<'EOF'

auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

auto vmbr1.10
iface vmbr1.10 inet static
    address 10.10.10.2/24
EOF
    changed=1
  fi

  if ! grep -q "^iface vmbr2 " /etc/network/interfaces; then
    cat >>/etc/network/interfaces <<'EOF'

auto vmbr2
iface vmbr2 inet static
    address 10.10.99.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF
    changed=1
  fi

  if [[ "${changed}" -eq 1 ]]; then
    ifreload -a
  fi

  if [[ ! -f /etc/dnsmasq.d/silab-build.conf ]]; then
    log "starting dnsmasq on the build network"
    cat >/etc/dnsmasq.d/silab-build.conf <<'EOF'
# Serves the disposable Packer build network only (vmbr2, 10.10.99.0/24) — see
# the host-network SPIKE in PLAN.md. Never touches vmbr1/VLAN 10, which has no
# DHCP scope by design (docs/network-design.md) — a second dhcp-range line
# here for vmbr1 would be a bug, not a convenience.
interface=vmbr2
bind-interfaces
except-interface=lo
dhcp-range=10.10.99.100,10.10.99.200,12h
# OPNsense's build VM has no guest agent, so it needs a fixed, knowable
# address instead — must match packer/opnsense.pkr.hcl's
# local.opnsense_build_mac/local.opnsense_build_ip exactly.
dhcp-host=02:00:00:00:99:10,10.10.99.10
EOF
    systemctl enable --now dnsmasq
  fi
}

# -- Stage: merge the first-boot hook's tokens into .env -------------------
stage_merge_tokens() {
  local token_file="/root/proxmox-api-tokens.txt"
  if [[ ! -f "${token_file}" ]]; then
    log "no ${token_file} — tokens already merged"
    return
  fi

  log "merging Proxmox API tokens into .env"
  local line name
  while IFS= read -r line; do
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    name="${line%%=*}"
    sed -i "s|^${name}=.*|${line}|" "${env_file}"
  done <"${token_file}"
  rm -f "${token_file}"

  set -a
  # shellcheck source=/dev/null
  . "${env_file}"
  set +a
}

# -- Stage: OPNsense's ISO, downloaded and decompressed by hand ------------
# packer/opnsense.pkr.hcl's boot_iso stays a plain iso_file reference —
# iso_download_pve cannot decompress .iso.bz2, so this is the explicit
# handling task 5 calls for, not an oversight.
pkrvars_value() {
  local key="$1" file="${repo_root}/packer/packer.auto.pkrvars.hcl"
  grep -E "^${key}[[:space:]]*=" "${file}" | head -1 |
    sed -E 's/^[^=]+=[[:space:]]*"([^"]*)".*/\1/'
}

stage_download_opnsense_iso() {
  local iso_file iso_url iso_checksum datastore_path
  iso_file="$(pkrvars_value opnsense_iso_file)"
  iso_url="$(pkrvars_value opnsense_iso_url)"
  iso_checksum="$(pkrvars_value opnsense_iso_checksum)"
  # Assumes the "local" datastore's default path, matching iso_datastore's own
  # default and docs/conventions.md's "local:iso/<file>" convention — not a
  # generic datastore lookup, since a non-directory storage type would not
  # have a filesystem path to write into at all.
  datastore_path="/var/lib/vz/template/iso/${iso_file}"

  if [[ -f "${datastore_path}" ]]; then
    log "OPNsense ISO already present at ${datastore_path}"
    return
  fi

  log "downloading and decompressing the OPNsense ISO"
  # See install_hashicorp_tool's comment on why this is a plain rm at the end
  # rather than a RETURN trap.
  local work
  work="$(mktemp -d)"

  curl -fsSL -o "${work}/opnsense.iso.bz2" "${iso_url}"
  bunzip2 -c "${work}/opnsense.iso.bz2" >"${work}/opnsense.iso"

  local expected="${iso_checksum#sha256:}" actual
  actual="$(sha256sum "${work}/opnsense.iso" | awk '{print $1}')"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "error: OPNsense ISO checksum mismatch (expected ${expected}, got ${actual})" >&2
    rm -rf "${work}"
    exit 1
  fi

  mkdir -p "$(dirname "${datastore_path}")"
  mv "${work}/opnsense.iso" "${datastore_path}"
  rm -rf "${work}"
}

# -- Stage: build any template that doesn't exist yet ----------------------
stage_build_templates() {
  local vmids=(9000 9001 9002)
  local sources=(
    "windows-templates.proxmox-iso.windows_server_2025"
    "windows-templates.proxmox-iso.windows_11"
    "opnsense-template.proxmox-iso.opnsense"
  )
  local missing=() i

  for i in "${!vmids[@]}"; do
    if ! qm status "${vmids[${i}]}" &>/dev/null; then
      missing+=("${sources[${i}]}")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "all three templates already exist"
    return
  fi

  local only
  only="$(
    IFS=,
    echo "${missing[*]}"
  )"
  log "building templates: ${only}"
  (cd "${repo_root}/packer" && packer init . && packer build "-only=${only}" .)
}

# -- Stage: clone and configure the firewall -------------------------------
stage_apply_firewall() {
  if qm status 101 &>/dev/null; then
    log "OPNsense guest (101) already exists"
  else
    log "cloning OPNsense from its template"
    (cd "${repo_root}/terraform" && terraform init && \
      terraform apply -auto-approve -target=proxmox_virtual_environment_vm.opnsense)
  fi
  log "applying opnsense/ (DHCP, firewall, NAT)"
  (cd "${repo_root}/opnsense" && terraform init && terraform apply -auto-approve)
}

# -- Wait for a guest's phase.json, via terraform/wait-for-guests.tf -------
# Reuses Terraform's own, already-pinned WinRM client rather than
# reimplementing the WinRM wire protocol in bash — see the orchestration
# SPIKE's second correction in PLAN.md. -replace forces a fresh connection
# attempt (and hence a fresh remote-exec) on every call; a failed attempt —
# unreachable mid-reboot, or not on its terminal phase yet — is just a
# nonzero exit to retry, never a tainted guest resource, since these
# terraform_data resources are entirely separate from the guests themselves.
wait_for_guest() {
  local resource="$1" label="$2" deadline=$((SECONDS + 3600)) log_file
  log_file="$(mktemp)"

  log "waiting for ${label}"
  while ((SECONDS < deadline)); do
    if (cd "${repo_root}/terraform" &&
      terraform apply -auto-approve -target="${resource}" -replace="${resource}") \
      >"${log_file}" 2>&1; then
      log "${label} ready"
      rm -f "${log_file}"
      return 0
    fi
    sleep 15
  done

  echo "error: timed out waiting for ${label}" >&2
  cat "${log_file}" >&2
  rm -f "${log_file}"
  return 1
}

stage_apply_dc01() {
  if ! qm status 201 &>/dev/null; then
    log "cloning and bootstrapping DC01"
    (cd "${repo_root}/terraform" && \
      terraform apply -auto-approve -target=proxmox_virtual_environment_vm.dc01)
  fi
  wait_for_guest "terraform_data.wait_dc01" "DC01 (phase 5)"
}

stage_apply_srv01_cl01() {
  if ! qm status 202 &>/dev/null || ! qm status 301 &>/dev/null; then
    log "cloning and bootstrapping SRV01 and CL01"
    (cd "${repo_root}/terraform" && terraform apply -auto-approve \
      -target=proxmox_virtual_environment_vm.srv01 \
      -target=proxmox_virtual_environment_vm.cl01)
  fi
  wait_for_guest "terraform_data.wait_srv01" "SRV01 (phase 2)"
  wait_for_guest "terraform_data.wait_cl01" "CL01 (phase 1)"
}

main() {
  stage_trust_proxmox_ca
  stage_install_tools
  stage_setup_networks
  stage_merge_tokens
  stage_download_opnsense_iso
  stage_build_templates
  stage_apply_firewall
  stage_apply_dc01
  stage_apply_srv01_cl01
  log "host runner finished — DC01, SRV01 and CL01 have all reached their terminal phase"
}

main "$@"
