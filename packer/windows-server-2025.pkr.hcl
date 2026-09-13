source "proxmox-iso" "windows_server_2025" {
  # -- Connection --
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = false
  node                     = var.proxmox_node

  # -- Template identity, per docs/conventions.md --
  vm_id                = 9000
  template_name        = "tpl-winsrv2025-de-v1"
  template_description = "Windows Server 2025, Desktop Experience, de-DE. Built by packer/windows-server-2025.pkr.hcl. No sysprep — see PLAN.md."
  tags                 = "lab;packer;winsrv2025"

  # -- Hardware shape --
  machine = "q35"
  bios    = "ovmf"
  cores   = 4
  memory  = 8192

  efi_config {
    efi_storage_pool  = var.template_datastore
    efi_type          = "4m"
    pre_enrolled_keys = false # Secure Boot is a Windows 11 requirement, not Server's — see windows-11.pkr.hcl.
  }

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = "80G"
    storage_pool = var.template_datastore
    type         = "scsi"
  }

  network_adapters {
    model  = "virtio"
    bridge = var.proxmox_bridge_build # disposable build network, not WAN — see the host-network SPIKE in PLAN.md.
  }

  # -- Installation media --
  # boot_iso, not the deprecated top-level iso_file/iso_checksum. Downloaded by
  # Proxmox itself (iso_download_pve) from win_server_iso_url — nothing crosses
  # the operator's connection, only the host's (task 5, PLAN.md). The URL's own
  # filename becomes the datastore filename, so it must end in exactly
  # win_server_iso_file (docs/conventions.md) for that table to stay honest.
  boot_iso {
    type             = "ide"
    iso_url          = var.win_server_iso_url
    iso_checksum     = var.win_server_iso_checksum
    iso_storage_pool = var.iso_datastore
    iso_download_pve = true
  }

  # Two separate CD-ROMs: the answer file generated on the fly, and the VirtIO
  # ISO already on the datastore. See autounattend-server.xml's header for why
  # its driver path hedges across drive letters instead of assuming one.
  additional_iso_files {
    cd_files         = ["files/autounattend-server.xml"]
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

  # A defensive keypress in case a "press any key to boot from CD/DVD" UEFI prompt
  # appears — harmless if it doesn't, since Setup ignores stray input once past it.
  boot_command = ["<enter>"]
  boot_wait    = "5s"

  # -- Communicator --
  # Password matches autounattend-server.xml's bootstrap AdministratorPassword —
  # not the real, sensitive local_admin_password. Generous timeout since a German
  # ISO applying Windows Update is slow, with no host yet to have timed it against.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = "Pa$$w0rd-PackerBuild!"
  winrm_timeout  = "6h"
}
