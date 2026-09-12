locals {
  # Doubling `'` escapes it in a single-quoted PowerShell arg, closing the
  # injection path when a password contains a quote. Passwords are still
  # visible in the guest's process list while the script runs — writing them
  # to a file instead is barred by PLAN.md's secrets decision (FIXES.md task 3).
  ps_local_admin_password   = replace(var.local_admin_password, "'", "''")
  ps_domain_admin_password  = replace(var.domain_admin_password, "'", "''")
  ps_dsrm_recovery_password = replace(var.dsrm_recovery_password, "'", "''")
}
