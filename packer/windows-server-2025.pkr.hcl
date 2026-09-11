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
    bridge = "vmbr0" # trunk bridge — see docs/hardware.md for the two viable NIC layouts.
  }

  # -- Installation media --
  iso_file     = "${var.iso_datastore}:iso/${var.win_server_iso_file}"
  iso_checksum = var.win_server_iso_checksum

  # Generated on the fly from the answer file, and the real VirtIO ISO already on
  # the datastore — two separate CD-ROMs. See autounattend-server.xml's header for
  # why the driver path inside it hedges across drive letters instead of assuming
  # a fixed one.
  additional_iso_files {
    cd_files = ["files/autounattend-server.xml"]
    cd_label = "unattend"
  }
  additional_iso_files {
    type         = "scsi"
    iso_file     = "${var.iso_datastore}:iso/${var.virtio_iso_file}"
    iso_checksum = var.virtio_iso_checksum
    unmount      = true
  }

  qemu_agent = true

  # A defensive keypress in case a "press any key to boot from CD/DVD" UEFI prompt
  # appears — harmless if it doesn't, since Setup ignores stray input once past it.
  boot_command = ["<enter>"]
  boot_wait    = "5s"

  # -- Communicator --
  # Password matches autounattend-server.xml's bootstrap AdministratorPassword
  # exactly — it is not the real, sensitive local_admin_password. Generous timeout
  # because a German ISO applying Windows Update is slow, and there is no host yet
  # to have actually timed it against.
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = "Pa$$w0rd-PackerBuild!"
  winrm_timeout  = "6h"
}
