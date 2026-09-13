# The bootstrap password config.xml's root user is built with — fixed and
# non-secret (same value the two Windows answer files use), never the real
# secret in .env. See the correction on PLAN.md's OPNsense SPIKE decision for
# why boot_command has to type something real here at all.
locals {
  opnsense_bootstrap_password      = "Pa$$w0rd-PackerBuild!"
  opnsense_bootstrap_password_hash = "$6$silabbootstrap01$je7lSx/SpZ64HHPPxIIE0W7LSPrjqvRi3RlLazRyOVU1C0UntEPlXKrNTQK05KReFqKCapGuO1jHuoULp7dQ.0"

  # No qemu-guest-agent on this build (FreeBSD), so Packer can't ask Proxmox
  # what address it picked — unlike the two Windows builds, this one needs a
  # fixed, knowable address instead. A locally-administered MAC (never a real
  # vendor OUI, same reasoning as docs/conventions.md's guest MAC scheme, but
  # this one is a build-only artifact, not a production guest — it never
  # appears in that table) paired with a matching static reservation in the
  # host-side runner's dnsmasq config (scripts/host-runner.sh). Both sides of
  # this pairing have to change together if either does.
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
  # No EFI/TPM: OPNsense/FreeBSD needs neither, unlike the Windows templates.
  # Two NICs in the same order vm-opnsense.tf's clone must declare them in —
  # the zero-touch SPIKE's vtnet0/vtnet1 naming only holds if that order never
  # drifts between this build and task 8's clone. Both land on the disposable
  # build bridge here, not vmbr0/vmbr1 — the guest's own OS has no idea which
  # physical/virtual bridge sits behind vtnet0 or vtnet1, only their PCI slot
  # order, so build-time and production bridge assignment can differ freely
  # (host-network SPIKE, PLAN.md). vtnet0 (WAN, first) gets a fixed MAC below
  # since this build has no other way to be addressed for SSH.
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
  boot_iso {
    type             = "ide"
    iso_file         = "${var.iso_datastore}:iso/${var.opnsense_iso_file}"
    iso_checksum     = var.opnsense_iso_checksum
    iso_storage_pool = var.iso_datastore
  }

  # The config-importer's carrier. OPNsense's own docs describe this as a
  # FAT/FAT32 USB drive specifically — whether its device scan also reads an
  # ISO9660 volume like this one is this milestone's biggest residual unknown
  # (PLAN.md, task 1's SPIKE). If the proof run shows it does not, this needs
  # to become a raw FAT32 disk image attached as an extra virtual disk instead.
  additional_iso_files {
    cd_content = {
      "conf/config.xml" = local.opnsense_config
    }
    cd_label         = "cfgimport"
    iso_storage_pool = var.iso_datastore
  }

  qemu_agent = false # FreeBSD/OPNsense has no qemu-guest-agent by default — matches vm-opnsense.tf.

  # Everything past "boot the installer media" here is unverified against a
  # real install — there is no host to test it on (PLAN.md). Each step below
  # is the documented bsdinstall/OPNsense sequence, not a guess at the
  # sequence itself, but the exact keystroke count per screen (arrow presses,
  # which option is highlighted by default) is the single least-verified
  # artifact in this milestone. Confirm against the Milestone 8 proof run
  # before trusting it unattended a second time.
  boot_command = [
    "<wait60s>",
    # "Press any key to start the configuration importer"
    "<enter>",
    "<wait5s>",
    # Device name prompt — "cd1" assumes the config carrier lands on the
    # second CD-ROM slot after the boot ISO's own "cd0". Unverified.
    "cd1<enter>",
    "<wait30s>",
    # Live environment login: prompt. Login itself launches bsdinstall for
    # the "installer" user (OPNsense docs) — no menu navigation needed.
    "installer<enter>",
    "<wait5s>",
    "${local.opnsense_bootstrap_password}<enter>",
    "<wait10s>",
    # Keymap selection — accept whatever bsdinstall defaults to.
    "<enter>",
    "<wait5s>",
    # Filesystem type (UFS/ZFS) — accept the default rather than gamble on
    # which one is highlighted first.
    "<enter>",
    "<wait5s>",
    # Disk selection — a single virtual disk, toggled with space then continue.
    "<spacebar><enter>",
    "<wait5s>",
    # "Last Chance!" format confirmation.
    "<enter>",
    "<wait2m>",
    # Post-install prompt (e.g. "open a shell for final customization?") —
    # accept the default, which should decline and proceed to reboot.
    "<enter>",
    "<wait10s>",
  ]
  boot_wait = "10s"

  # -- Communicator --
  # SSH, not WinRM — config.xml's <ssh><group>admins</group> block enables it
  # for the bootstrap login. The rotation provisioner below is what actually
  # needs it, exactly once. No guest agent (qemu_agent = false above) means
  # Packer has no way to discover this VM's address on its own, unlike the two
  # Windows builds — ssh_host names it explicitly instead, the fixed
  # reservation local.opnsense_build_mac gets from the runner's dnsmasq.
  communicator = "ssh"
  ssh_host     = local.opnsense_build_ip
  ssh_username = "root"
  ssh_password = local.opnsense_bootstrap_password
  ssh_timeout  = "45m"
}

# Its own build block, not the Windows "windows-templates" one — the two
# guest families share nothing provisioner-side (SSH/shell here, WinRM/
# PowerShell there), but `packer validate .` covers both with no workflow
# change either way, since it runs over every .pkr.hcl in the directory.
build {
  name    = "opnsense-template"
  sources = ["source.proxmox-iso.opnsense"]

  # Rotates root to the real password and persists it into config.xml so a
  # later reboot (Terraform's first clone included) can't revert it back to
  # the bootstrap value — see the file header on rotate-opnsense-root-password.sh.
  provisioner "shell" {
    script = "files/rotate-opnsense-root-password.sh"
    environment_vars = [
      "ROOT_PASSWORD=${var.opnsense_root_password}",
      "BOOTSTRAP_HASH=${local.opnsense_bootstrap_password_hash}",
    ]
  }
}
