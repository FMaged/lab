provider "proxmox" {
  # endpoint, api_token and insecure all come from PROXMOX_VE_ENDPOINT,
  # PROXMOX_VE_API_TOKEN and PROXMOX_VE_INSECURE — the provider reads these
  # itself when the block omits them. Never put a real endpoint or token here.
  # See the secrets decision in PLAN.md.
}
