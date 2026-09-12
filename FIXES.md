# Fixes

Findings from a review of the merged Terraform and PowerShell layers. Same format as
`TASKS.md` — one task, one commit — but kept separate because these are corrections to
landed work rather than a milestone.

Ordered by severity: 1 stops the client from booting at all, 2 and 3 fail silently or
unsafely, and 9 is cosmetic. Each was verified against the code on
`bugfix/no-ref/review-fixes` before being written down.

None of this can be tested here. Every `Accept` line is checkable by reading the diff or
by `terraform validate` / PSScriptAnalyzer, except where it says otherwise.

1. [x] Set the EFI firmware type and pre-enrolled keys on all three Windows guests
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

   Notes: also corrected the comment that claimed no such argument existed, verified against the bpg/proxmox 0.112.0 documentation rather than the latest. Applied to all three guests, not just CL01 — the servers are UEFI too. One impurity: the follow-up that moved the explanatory comment above the block, so `terraform fmt` alignment is unambiguous, landed in task 9's commit by a mistaken amend rather than this one.

2. [x] Do not trust a phase marker whose result is independently checkable
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

   Notes: added `Assert-SILabPhaseEffect` to `SILab.psm1` rather than repeating the throw three times. Guarded exactly the three phases that write their marker before a rebooting call — DC01 phase 2, SRV01 phase 2, CL01 phase 1. Every other phase sets its marker after the work completes, so it cannot lie, and guarding them would have been noise.

3. [x] Stop passing passwords on the guest command line
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

   Notes: escaped, not re-plumbed. `terraform/locals.tf` doubles every single quote before interpolation, which closes the injection and stays inside the secrets decision. **The process-list exposure is still open:** the passwords remain visible to any local user on the guest while the script runs. Closing that means writing them to the guest's disk, which `PLAN.md` forbids in those words, so it needs the decision amended first. Left deliberately.

4. [x] Turn on NTLM encryption for the WinRM connections
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

   Notes: one line per guest plus a comment on `vm-dc01.tf` explaining why `https = false` and `use_ntlm = true` belong together — HTTPS needs a certificate the template does not carry, and setting only one of the two is the actual mistake.

5. [x] Qualify the domain in the join credential
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

   Notes: used the UPN form built from the `$script:ForestDomainName` already defined in each script, so no second literal of the domain exists to drift. DC01 needed no change: it sets the local Administrator password directly and never builds a credential.

6. [x] Fail the template lookup with a message instead of an index error
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

   Notes: **Deviation from the plan.** Written as `postcondition` blocks on the two data sources rather than `precondition` blocks on the three VM resources. The failure belongs to the lookup, not to any one guest, and DC01 and SRV01 share a data source — so this is two blocks instead of three with no duplicated message.

7. [x] Add a CI check that the two Terraform roots agree on MACs and addresses
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

   Notes: implemented as `.github/scripts/check-design-consistency.py` so it runs locally too, wired into `validate.yml` as a `consistency` job. It checks code against the design documents rather than root against root: `AGENTS.md` already requires changing the document first, so anchoring there makes the roots agree as a consequence and also catches a value invented in code that both roots happen to share. Case is normalised, so today's uppercase/lowercase MAC difference passes. Proven both ways: changing a MAC in `terraform/` only and an address in `opnsense/` only each produced a failure naming the file and line.

8. [x] Verify the disk and guest agent assumptions on the first real apply
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

   Notes: the assumptions held — 80 GB and 64 GB match their templates, both use `virtio-scsi-single`, and the guest tools installer does install the agent. But it never checked its own exit code, and `Start-Process -Wait` sets neither `$LASTEXITCODE` nor throws, so a failed install was silent and would have surfaced exactly as the predicted agent hang. Now `-PassThru` with 0 and 3010 accepted. Both checks added to the runbook.

9. [x] Remove the stale "does not exist yet" comments
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

   Notes: both removed. The wider grep found no other forward reference that has come true anywhere in `terraform/`, `opnsense/`, `packer/`, `powershell/` or `.github/`. The two remaining milestone references, both in `Bootstrap-DC01.ps1`, point at Milestone 8 and are still accurate.

10. [x] Replace the link checker that downloads a binary to check local links
    **What:** the `links` job, which used `lycheeverse/lychee-action@v2`, replaced with
    `.github/scripts/check-markdown-links.py`.
    **Why:** the job failed with `curl` exit 35, a TLS handshake error, while downloading
    lychee's own release binary. The repository was fine; the release tag it asked for
    exists. But per the CI decision in `PLAN.md` this harness is the project's only
    feedback loop, and it was depending on a 20 MB download from a third party on every
    single run — while passing `--exclude '^https?://'`, so it only ever checked relative
    links, which needs no network whatsoever.
    **How:** same pattern as the design consistency check — a script in `.github/scripts/`
    that also runs locally. No downloads, no action pinning to maintain.
    **Accept:** the job runs with no network access; a dead relative link and a dead
    heading anchor each turn it red, demonstrated; no lychee reference remains outside the
    comment explaining the change.

    Notes: 72 relative links across 23 files, none broken. Both failure kinds proven on
    scratch edits. The replacement is strictly stronger than what it replaced: it also
    validates `#anchor` targets against the headings in the file they point at, which the
    old invocation did not — that is what keeps the generated decision index in `PLAN.md`
    honest. Re-running the old job would probably have succeeded, since the failure was
    transient; it was replaced because the dependency was unnecessary, not because it was
    broken.
