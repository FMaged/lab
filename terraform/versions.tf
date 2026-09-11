terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.112.0" # pinned 2026-09-11 — latest release, published 2026-09-03
    }
  }
}
