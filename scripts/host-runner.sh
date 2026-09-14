#!/usr/bin/env bash
# Runs on the Proxmox host after deploy.sh; every stage skips work already done, so re-runs are safe.
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: run as root" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${repo_root}/.env"
tools_dir="/opt/silab-tools"
# Must match the pins in AGENTS.md.
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

# Lets Packer and Terraform keep TLS verification on.
stage_trust_proxmox_ca() {
  log "trusting pve-root-ca"
  if [[ ! -f /usr/local/share/ca-certificates/pve-root-ca.crt ]]; then
    cp /etc/pve/pve-root-ca.pem /usr/local/share/ca-certificates/pve-root-ca.crt
    update-ca-certificates
  fi
  # answer.toml's fixed fqdn; no DNS server exists yet.
  if ! grep -qF "pve.silab.internal" /etc/hosts; then
    echo "127.0.0.1 pve.silab.internal" >>/etc/hosts
  fi
}

install_hashicorp_tool() {
  local name="$1" version="$2"
  local bin="${tools_dir}/${name}"

  if [[ -x "${bin}" ]] && "${bin}" version 2>/dev/null | head -1 | grep -qF "${version}"; then
    log "${name} ${version} already installed"
    return
  fi

  log "installing ${name} ${version}"
  # No RETURN trap: it would also fire on every enclosing function's return.
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

# Done here, not in first-boot-hook.sh, so a provider's stock Proxmox image works too.
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
# Build network only; vmbr1/VLAN 10 has no DHCP by design.
interface=vmbr2
bind-interfaces
except-interface=lo
dhcp-range=10.10.99.100,10.10.99.200,12h
# No guest agent on OPNsense; must match opnsense_build_mac/ip in packer/opnsense.pkr.hcl.
dhcp-host=02:00:00:00:99:10,10.10.99.10
EOF
    systemctl enable --now dnsmasq
  fi
}

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

pkrvars_value() {
  local key="$1" file="${repo_root}/packer/packer.auto.pkrvars.hcl"
  grep -E "^${key}[[:space:]]*=" "${file}" | head -1 |
    sed -E 's/^[^=]+=[[:space:]]*"([^"]*)".*/\1/'
}

# Packer's iso_download_pve can't decompress .iso.bz2.
stage_download_opnsense_iso() {
  local iso_file iso_url iso_checksum datastore_path
  iso_file="$(pkrvars_value opnsense_iso_file)"
  iso_url="$(pkrvars_value opnsense_iso_url)"
  iso_checksum="$(pkrvars_value opnsense_iso_checksum)"
  # Assumes the default "local" datastore.
  datastore_path="/var/lib/vz/template/iso/${iso_file}"

  if [[ -f "${datastore_path}" ]]; then
    log "OPNsense ISO already present at ${datastore_path}"
    return
  fi

  log "downloading and decompressing the OPNsense ISO"
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

# Polls terraform/wait-for-guests.tf; -replace forces a fresh WinRM check on each try.
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

stage_run_health_check() {
  log "running Test-SILab.ps1 on DC01"
  (cd "${repo_root}/terraform" && terraform apply -auto-approve \
    -target=terraform_data.run_health_check \
    -replace=terraform_data.run_health_check)
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

  if stage_run_health_check; then
    log "PASS — Test-SILab.ps1 found nothing wrong. Scrubbing secrets from the host."
    "${repo_root}/scripts/scrub-host.sh"
    exit 0
  fi

  log "FAIL — Test-SILab.ps1 found a problem. State is kept so a re-run can continue."
  log "Before releasing this server, scrub it by hand: ${repo_root}/scripts/scrub-host.sh"
  exit 1
}

main "$@"
