locals {
  # Passwords are interpolated into single-quoted PowerShell arguments in each
  # guest's remote-exec. A single quote inside a password would close that string
  # early and everything after it would execute as PowerShell — command injection
  # through a credential the operator chooses. Doubling is PowerShell's escape for
  # a literal quote inside a single-quoted string.
  #
  # This does not hide the passwords from the guest's process list while the
  # script runs. Closing that would mean writing them to a file on the guest,
  # which the secrets decision in PLAN.md forbids in those words — so it is a
  # decision to amend first, not a change to make quietly. See FIXES.md task 3.
  ps_local_admin_password   = replace(var.local_admin_password, "'", "''")
  ps_domain_admin_password  = replace(var.domain_admin_password, "'", "''")
  ps_dsrm_recovery_password = replace(var.dsrm_recovery_password, "'", "''")
}
