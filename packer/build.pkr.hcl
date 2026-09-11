# One build block, both sources — the two templates are a matched pair (see the
# packer-windows skill), so they run the same provisioner chain instead of two
# near-identical build blocks that would drift apart over time.
build {
  name = "windows-templates"
  sources = [
    "source.proxmox-iso.windows_server_2025",
    "source.proxmox-iso.windows_11",
  ]

  # 1. QEMU guest agent + the rest of the VirtIO drivers.
  provisioner "powershell" {
    script = "files/install-guest-tools.ps1"
  }

  # 2. Windows Updates — plugin pinned in plugins.pkr.hcl.
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    update_limit = 50
  }

  # 3. Cleanup — explicitly no sysprep, see PLAN.md and cleanup.ps1.
  provisioner "powershell" {
    script = "files/cleanup.ps1"
  }

  # 4. Rotate the bootstrap password to the real one. Must run last — see
  # rotate-admin-password.ps1 and the answer files' headers for why.
  provisioner "powershell" {
    script = "files/rotate-admin-password.ps1"
    environment_vars = [
      "ADMIN_PASSWORD=${var.local_admin_password}",
    ]
  }
}
