# Fixed, non-secret bootstrap password for config.xml's root user, never the real secret in .env.
locals {
  opnsense_bootstrap_password      = "Pa$$w0rd-PackerBuild!"
  opnsense_bootstrap_password_hash = "$6$silabbootstrap01$je7lSx/SpZ64HHPPxIIE0W7LSPrjqvRi3RlLazRyOVU1C0UntEPlXKrNTQK05KReFqKCapGuO1jHuoULp7dQ.0"

  # No qemu-guest-agent (FreeBSD), so a fixed MAC/IP is needed; must match host-runner.sh's dnsmasq reservation.
  opnsense_build_mac = "02:00:00:00:99:10"
  opnsense_build_ip  = "10.10.99.10"

  opnsense_config = templatefile("${path.root}/files/config.xml", {
    opnsense_bootstrap_password_hash = local.opnsense_bootstrap_password_hash
    opnsense_api_key                 = var.opnsense_api_key
    opnsense_api_secret_hash         = var.opnsense_api_secret_hash
  })
}

source "proxmox-iso" "opnsense" {
  # -- Connection --
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = false
  node                     = var.proxmox_node

  # -- Template identity, per docs/conventions.md --
  vm_id                = 9002
  template_name        = "tpl-opnsense-v1"
  template_description = "OPNsense, config baked in via the live-image importer. Built by packer/opnsense.pkr.hcl. See the zero-touch decision in PLAN.md."
  tags                 = "lab;packer;opnsense"

  # -- Hardware shape --
  # No EFI/TPM: FreeBSD needs neither. NIC order must match vm-opnsense.tf's clone (vtnet0=WAN, vtnet1=LAN).
  machine = "q35"
  bios    = "seabios"
  cores   = 2
  memory  = 2048

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = "32G"
    storage_pool = var.template_datastore
    type         = "scsi"
  }

  network_adapters {
    model       = "virtio"
    bridge      = var.proxmox_bridge_build
    mac_address = local.opnsense_build_mac
  }
  network_adapters {
    model  = "virtio"
    bridge = var.proxmox_bridge_build
  }

  # -- Installation media --
  # iso_download_pve can't decompress OPNsense's .iso.bz2; host-runner.sh downloads and verifies it first.
  boot_iso {
    type             = "ide"
    iso_file         = "${var.iso_datastore}:iso/${var.opnsense_iso_file}"
    iso_checksum     = var.opnsense_iso_checksum
    iso_storage_pool = var.iso_datastore
  }

  # OPNsense's config importer expects a FAT/FAT32 USB drive; unverified whether it also reads this ISO9660 volume.
  additional_iso_files {
    cd_content = {
      "conf/config.xml" = local.opnsense_config
    }
    cd_label         = "cfgimport"
    iso_storage_pool = var.iso_datastore
  }

  qemu_agent = false # matches vm-opnsense.tf

  # Documented bsdinstall/OPNsense sequence; unverified against a real install (no host to test on yet).
  boot_command = [
    "<wait60s>",
    "<enter>", # start the configuration importer
    "<wait5s>",
    "cd1<enter>", # assumes the config carrier lands on cd1 after the boot ISO's cd0; unverified
    "<wait30s>",
    "installer<enter>", # live environment login launches bsdinstall directly
    "<wait5s>",
    "${local.opnsense_bootstrap_password}<enter>",
    "<wait10s>",
    "<enter>", # keymap: accept default
    "<wait5s>",
    "<enter>", # filesystem type: accept default
    "<wait5s>",
    "<spacebar><enter>", # disk selection: toggle the single virtual disk, continue
    "<wait5s>",
    "<enter>", # "Last Chance!" format confirmation
    "<wait2m>",
    "<enter>", # post-install prompt: accept default (decline shell, reboot)
    "<wait10s>",
  ]
  boot_wait = "10s"

  # -- Communicator --
  # SSH: config.xml's <ssh><group>admins</group> enables it for the bootstrap login.
  communicator = "ssh"
  ssh_host     = local.opnsense_build_ip
  ssh_username = "root"
  ssh_password = local.opnsense_bootstrap_password
  ssh_timeout  = "45m"
}

build {
  name    = "opnsense-template"
  sources = ["source.proxmox-iso.opnsense"]

  # Rotates root to the real password and persists it into config.xml so a later reboot can't revert it.
  provisioner "shell" {
    script = "files/rotate-opnsense-root-password.sh"
    environment_vars = [
      "ROOT_PASSWORD=${var.opnsense_root_password}",
      "BOOTSTRAP_HASH=${local.opnsense_bootstrap_password_hash}",
    ]
  }
}
