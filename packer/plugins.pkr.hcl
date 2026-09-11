packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "1.2.3" # pinned 2026-09-11 — latest release
    }
    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = "0.18.4" # pinned 2026-09-11 — latest release, published 2026-07-10
    }
  }
}
