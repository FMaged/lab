source "proxmox-iso" "windows_11" {
  # -- Connection --
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = false
  node                     = var.proxmox_node

  # -- Template identity, per docs/conventions.md --
  vm_id                = 9001
  template_name        = "tpl-win11-de-v1"
  template_description = "Windows 11 Pro, de-DE. Built by packer/windows-11.pkr.hcl. No sysprep — see PLAN.md."
  tags                 = "lab;packer;win11"

  # -- Hardware shape --
  # Same shape as windows-server-2025.pkr.hcl, plus TPM 2.0 and Secure Boot,
  # which Windows 11 enforces and Server doesn't — real hardware, not a bypass
  # (PLAN.md Windows 11 SPIKE decision).
  machine = "q35"
  bios    = "ovmf"
  cores   = 4
  memory  = 4096

  efi_config {
    efi_storage_pool  = var.template_datastore
    efi_type          = "4m"
    pre_enrolled_keys = true # Secure Boot, with Microsoft's standard keys pre-loaded.
  }

  tpm_config {
    tpm_storage_pool = var.template_datastore
    tpm_version      = "v2.0"
  }

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = "64G"
    storage_pool = var.template_datastore
    type         = "scsi"
  }

  network_adapters {
    model  = "virtio"
    bridge = var.proxmox_bridge_build # disposable build network, not WAN — see the host-network SPIKE in PLAN.md.
  }

  # -- Installation media --
  # boot_iso, not the deprecated top-level iso_file/iso_checksum. Downloaded by
  # Proxmox itself (iso_download_pve) — see windows-server-2025.pkr.hcl's
  # matching comment on why the URL's filename has to match docs/conventions.md.
  boot_iso {
    type             = "ide"
    iso_url          = var.win11_iso_url
    iso_checksum     = var.win11_iso_checksum
    iso_storage_pool = var.iso_datastore
    iso_download_pve = true
  }

  additional_iso_files {
    cd_files         = ["files/autounattend-client.xml"]
    cd_label         = "unattend"
    iso_storage_pool = var.iso_datastore
  }
  additional_iso_files {
    type             = "scsi"
    iso_url          = var.virtio_iso_url
    iso_checksum     = var.virtio_iso_checksum
    iso_storage_pool = var.iso_datastore
    iso_download_pve = true
    unmount          = true
  }

  qemu_agent = true

  boot_command = ["<enter>"]
  boot_wait    = "5s"

  # -- Communicator --
  # Password matches autounattend-client.xml's bootstrap LocalAccount password
  # exactly — not the real, sensitive local_admin_password.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = "Pa$$w0rd-PackerBuild!"
  winrm_timeout  = "6h"
}
