# Fixes

Findings from a review of the merged Terraform and PowerShell layers. Same format as
`TASKS.md` — one task, one commit — but kept separate because these are corrections to
landed work rather than a milestone.

Ordered by severity: 1 stops the client from booting at all, 2 and 3 fail silently or
unsafely, and 9 is cosmetic. Each was verified against the code on
`bugfix/no-ref/review-fixes` before being written down.

None of this can be tested here. Every `Accept` line is checkable by reading the diff or
by `terraform validate` / PSScriptAnalyzer, except where it says otherwise.

1. [ ] Set the EFI firmware type and pre-enrolled keys on all three Windows guests
   **What:** `type = "4m"` and `pre_enrolled_keys = true` in the `efi_disk` block of
   `vm-dc01.tf`, `vm-srv01.tf` and `vm-cl01.tf`, and the comment in `vm-cl01.tf` corrected.
   **Why:** all three currently set only `datastore_id`. The bpg/proxmox docs for the
   pinned **0.112.0** say `type` defaults to `2m`, that `4m` is "required for Secure Boot",
   and that `pre_enrolled_keys` defaults to `false`. So Secure Boot cannot work as
   configured, and Windows 11 Setup refuses to install without it. The comment in
   `vm-cl01.tf` asserts the opposite — that no such argument exists and the keys ship in
   the firmware regardless — which is wrong on both counts and would send the next reader
   looking in the wrong place.
   **How:** add both arguments to each `efi_disk` block. Replace the comment with what the
   0.112.0 documentation actually says. The servers need it too: `docs/hardware.md` requires
   UEFI with CSM off, and the Packer builds create their templates that way.
   **Accept:** all three `efi_disk` blocks set `type = "4m"` and `pre_enrolled_keys = true`;
   no comment claims the argument does not exist; `terraform validate` passes.

   Notes:

2. [ ] Do not trust a phase marker whose result is independently checkable
   **What:** a guard in `Bootstrap-CL01.ps1`, `Bootstrap-SRV01.ps1` and `Bootstrap-DC01.ps1`
   that fails loudly when a phase is marked complete but its effect is absent.
   **Why:** the marker is deliberately written *before* the call that reboots, because
   `Add-Computer -Restart` and `Install-ADDSForest` never return. The cost is that a join
   which fails for any reason — wrong password, DC not answering, OU missing — still leaves
   the phase marked complete. Re-running then takes the `else` branch, unregisters the
   resume task and exits zero. The machine is never joined and nothing anywhere says so.
   DC01 is worse: a failed promotion in phase 2 leaves the resume proceeding into phase 3's
   site rename against a domain that does not exist.
   **How:** check the world, not the marker. For the members,
   `(Get-CimInstance Win32_ComputerSystem).PartOfDomain`; for DC01, that the domain role is
   a domain controller. Throw with a message naming the phase. Keep writing the marker
   before the reboot — that part is correct and the decision in `PLAN.md` explains why.
   **Accept:** each script throws a named error when its phase marker is set but the
   corresponding state is absent; the marker is still written before the rebooting call;
   PSScriptAnalyzer clean.

   Notes:

3. [ ] Stop passing passwords on the guest command line
   **What:** the three `remote-exec` invocations in `vm-dc01.tf`, `vm-srv01.tf` and
   `vm-cl01.tf`, which interpolate passwords into a single-quoted PowerShell argument.
   **Why:** two problems. A password containing a single quote terminates the string early
   and whatever follows is executed as PowerShell — that is command injection through a
   credential the operator chooses. And for as long as the script runs, every password is
   visible in the guest's process list to any local user. DC01 is the worst case: it passes
   three, including the directory restore password.
   **How:** there are two routes and they are not equivalent. Escaping
   (`replace(var.domain_admin_password, "'", "''")`) closes the injection in one line and
   stays inside the current secrets decision, but leaves the passwords on the process
   command line. Delivering them as a file the script reads and deletes closes both, but
   writes a secret to the guest's disk — which the secrets decision in `PLAN.md` forbids in
   those words. Taking that route means amending the decision first, not quietly
   contradicting it.
   **Accept:** no password can terminate its quoting, demonstrated by reasoning about a
   password containing `'`; if the file route is chosen, `PLAN.md` carries an amended
   secrets decision in the same commit; `terraform validate` passes.

   Notes:

4. [ ] Turn on NTLM encryption for the WinRM connections
   **What:** `use_ntlm = true` on the three `connection` blocks, which currently set
   `https = false` and nothing else.
   **Why:** without it the local administrator password crosses the network base64-encoded
   and not encrypted. Inside a lab VLAN that is survivable, and the existing comment says
   so — but the whole point of the project is that a reviewer reads it, and this is exactly
   the line they will stop on. NTLM gives encrypted message payloads over the same port
   5985, so the cost is one line.
   **How:** add the argument to each connection block and rewrite the comment to say what
   is now true. Keep `https = false`: HTTPS needs a certificate the image does not have,
   which is a larger change than this fix.
   **Accept:** all three connection blocks set `use_ntlm = true`; no comment still describes
   the traffic as unencrypted; `terraform validate` passes.

   Notes:

5. [ ] Qualify the domain in the join credential
   **What:** `New-Object PSCredential -ArgumentList 'Administrator', $securePassword` in
   `Bootstrap-CL01.ps1` and `Bootstrap-SRV01.ps1`.
   **Why:** a bare `Administrator` is ambiguous and can resolve to the machine's local
   account rather than the domain's. On a machine that is not yet joined that is exactly
   the wrong resolution, and the resulting failure says nothing useful about the cause.
   **How:** `'SILAB\Administrator'` or `'Administrator@ad.silab.internal'`, taken from
   `docs/ad-design.md` rather than typed. Both scripts already hold the domain name in a
   script-scope variable; use it instead of a second literal.
   **Accept:** neither script builds a credential from an unqualified username; the domain
   comes from the existing variable, not a new literal; PSScriptAnalyzer clean.

   Notes:

6. [ ] Fail the template lookup with a message instead of an index error
   **What:** a `lifecycle` precondition on each of the three VM resources that use
   `data.proxmox_virtual_environment_vms.<template>.vms[0]`.
   **Why:** if the template is missing, renamed, or the Packer build has not run, the
   current code fails on an out-of-range index — an error that names neither the template
   nor the cause. The first real apply is the most likely moment for this, and it is also
   the moment the operator has the least context.
   **How:** a precondition asserting exactly one match, with an error message naming the
   template from `docs/conventions.md` and saying to run the Packer build first. One per
   guest, since the client looks up a different template from the servers.
   **Accept:** each VM resource using `vms[0]` has a precondition asserting a single match;
   each error message names the specific template and the corrective action;
   `terraform validate` passes.

   Notes:

7. [ ] Add a CI check that the two Terraform roots agree on MACs and addresses
   **What:** a job in `.github/workflows/validate.yml` comparing every MAC address and IP
   in `terraform/` and `opnsense/` against the tables in `docs/conventions.md` and
   `docs/network-design.md`.
   **Why:** the MAC is the interface between the two roots — `docs/walkthrough.md` says so
   in as many words — and nothing enforces it. Change one side alone and the guest boots
   with no address, with nothing in a plan or a validate run to explain why. The values are
   currently typed by hand in three places, counting `terraform/outputs.tf`.
   **How:** extract and compare, failing on any value present in one root and not the other,
   or in neither document. **Normalise case first:** `terraform/` writes
   `02:00:00:00:01:2D` and `opnsense/dhcp.tf` writes `02:00:00:00:01:2d` today, which is
   harmless to DHCP and would be a false failure for a naive comparison. Prove it catches a
   real break the way Milestone 2 task 8 did.
   **Accept:** the job passes on the current tree despite the existing case difference;
   changing a MAC in one root only turns it red, demonstrated on a scratch commit;
   the check names which file disagrees with which.

   Notes:

8. [ ] Verify the disk and guest agent assumptions on the first real apply
   **What:** two assumptions in the VM definitions that only a real apply can settle,
   recorded as explicit checks in `docs/runbook.md` rather than left implicit.
   **Why:** `disk { interface = "scsi0", size = 64 }` must match what the Packer build
   actually produced — a full clone will add a second disk or refuse outright if it
   disagrees, and a clone cannot shrink. And `agent { enabled = true }` makes Terraform wait
   for the QEMU guest agent, so if the image does not have it installed the apply does not
   fail, it hangs until timeout. Both are Milestone 8 failures waiting to happen, and both
   are cheap to check beforehand.
   **How:** cross-read the disk size and controller against `packer/windows-11.pkr.hcl` and
   `packer/windows-server-2025.pkr.hcl` now, and confirm `install-guest-tools.ps1` really
   installs the agent. Add both as explicit verification steps in the runbook's section 4
   and 5 so the proof run checks rather than assumes.
   **Accept:** the disk size and interface in each VM file provably match its template's
   build file, or the mismatch is recorded; the guest agent's installation is confirmed in
   the Packer provisioner; the runbook names both as checks.

   Notes:

9. [ ] Remove the stale "does not exist yet" comments
   **What:** `vm-cl01.tf:88` and `vm-srv01.tf:64`, both still saying the Bootstrap script
   they invoke does not exist and arrives in Milestone 6.
   **Why:** both scripts exist. In a repository whose stated pitch is that the
   documentation is part of the deliverable, a comment contradicting the file next to it
   costs more credibility than its size suggests. `vm-dc01.tf` does not have the problem, so
   this is two lines.
   **How:** delete or rewrite both. Then grep the whole tree for other forward references
   that have since come true — the Milestone 7 audit cleared the documents but did not look
   inside the code.
   **Accept:** no comment in any layer claims a file exists later that exists now; a grep
   for "does not exist yet" across the repository returns nothing.

   Notes:
