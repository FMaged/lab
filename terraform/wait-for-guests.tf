# terraform_data resources whose only job is a fresh WinRM connection per poll
# attempt — reusing Terraform's own, already-pinned WinRM client rather than
# reimplementing the WinRM wire protocol (SOAP over HTTP/NTLM) in the host-side
# runner's shell script. See the orchestration SPIKE in PLAN.md: `curl --ntlm`
# only carries the transport and auth, not the CreateShell/Command/Receive
# sequence WinRM actually needs, which is not something to hand-build in bash.
#
# The runner polls with `terraform apply -target=... -replace=...`, forcing a
# new connection attempt (and hence a fresh remote-exec) on every call. Each
# command exits non-zero when the guest hasn't reached its terminal phase yet
# or is unreachable (mid-reboot) — exactly what "keep retrying" means to a
# shell loop wrapped around `terraform apply`. `terraform_data` is a Terraform
# core builtin (1.4+, well under the pinned 1.16.1) — no provider to declare.

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

  # DC01's terminal phase is 5 (Bootstrap-DC01.ps1) — read directly from the
  # script, not assumed.
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

  # CL01's terminal phase is 1 (Bootstrap-CL01.ps1) — no addressing phase, it
  # stays on DHCP permanently, so DomainJoin is both its first and last phase.
  provisioner "remote-exec" {
    inline = [
      "powershell -NoProfile -Command \"$n = (Get-Content -Raw C:\\ProgramData\\SILab\\phase.json | ConvertFrom-Json).Number; if ($n -lt 1) { exit 1 }\"",
    ]
  }
}

# The deployment's actual verdict (task 10) — only runs once every guest has
# reached its terminal phase. Test-SILab.ps1 is already on DC01 (vm-dc01.tf's
# own `file` provisioner copies all of powershell/), is read-only, and exits
# non-zero if anything it checks is missing — that exit code becomes
# powershell.exe's own process exit code when run via -File, which is what
# makes this resource's success or failure the health check's own.
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
