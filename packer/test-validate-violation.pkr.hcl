source "proxmox-iso" "test" {
  # Intentionally missing every required argument, to trip `packer validate`.
}

build {
  sources = ["source.proxmox-iso.test"]
}
