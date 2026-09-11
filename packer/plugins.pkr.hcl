packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "1.2.3" # pinned 2026-09-11 — latest release
    }
  }
}
