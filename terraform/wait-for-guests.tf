# Reuses Terraform's own pinned WinRM client rather than reimplementing the WinRM wire protocol in
# bash. host-runner.sh polls with `terraform apply -target=... -replace=...`, forcing a fresh
# connection attempt each call; a nonzero exit means "not ready yet, keep retrying".

resource "terraform_data" "wait_dc01" {
  depends_on = [proxmox_virtual_environment_vm.dc01]

  connection {
    type     = "winrm"
    host     = "10.10.20.10"
    user     = "Administrator"
    password = var.local_admin_password
    https    = false
    use_ntlm = true
    timeout  = "30s"
  }

  # DC01's terminal phase is 5 (Bootstrap-DC01.ps1).
  provisioner "remote-exec" {
    inline = [
      "powershell -NoProfile -Command \"$n = (Get-Content -Raw C:\\ProgramData\\SILab\\phase.json | ConvertFrom-Json).Number; if ($n -lt 5) { exit 1 }\"",
    ]
  }
}

resource "terraform_data" "wait_srv01" {
  depends_on = [proxmox_virtual_environment_vm.srv01]

  connection {
    type     = "winrm"
    host     = "10.10.20.11"
    user     = "Administrator"
    password = var.local_admin_password
    https    = false
    use_ntlm = true
    timeout  = "30s"
  }

  # SRV01's terminal phase is 2 (Bootstrap-SRV01.ps1).
  provisioner "remote-exec" {
    inline = [
      "powershell -NoProfile -Command \"$n = (Get-Content -Raw C:\\ProgramData\\SILab\\phase.json | ConvertFrom-Json).Number; if ($n -lt 2) { exit 1 }\"",
    ]
  }
}

resource "terraform_data" "wait_cl01" {
  depends_on = [proxmox_virtual_environment_vm.cl01]

  connection {
    type     = "winrm"
    host     = "10.10.30.50"
    user     = "Administrator"
    password = var.local_admin_password
    https    = false
    use_ntlm = true
    timeout  = "30s"
  }

  # CL01's terminal phase is 1 (Bootstrap-CL01.ps1) — stays on DHCP, so DomainJoin is its only phase.
  provisioner "remote-exec" {
    inline = [
      "powershell -NoProfile -Command \"$n = (Get-Content -Raw C:\\ProgramData\\SILab\\phase.json | ConvertFrom-Json).Number; if ($n -lt 1) { exit 1 }\"",
    ]
  }
}

# Test-SILab.ps1 is already on DC01 via vm-dc01.tf's `file` provisioner; its exit code becomes this
# resource's success or failure.
resource "terraform_data" "run_health_check" {
  depends_on = [
    terraform_data.wait_dc01,
    terraform_data.wait_srv01,
    terraform_data.wait_cl01,
  ]

  connection {
    type     = "winrm"
    host     = "10.10.20.10"
    user     = "Administrator"
    password = var.local_admin_password
    https    = false
    use_ntlm = true
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:/lab-provisioning/Test-SILab.ps1",
    ]
  }
}
