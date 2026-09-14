locals {
  # Doubling `'` escapes it in a single-quoted PowerShell arg, closing the injection path
  # when a password contains a quote. Still visible in the guest's process list while it runs.
  ps_local_admin_password   = replace(var.local_admin_password, "'", "''")
  ps_domain_admin_password  = replace(var.domain_admin_password, "'", "''")
  ps_dsrm_recovery_password = replace(var.dsrm_recovery_password, "'", "''")
}
