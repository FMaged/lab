---
name: powershell-provisioning
description: Conventions for this repo's powershell/ layer — the three Bootstrap-DC01/SRV01/CL01.ps1 entry points Terraform invokes, the SILab.psm1 module, the phase-marker and scheduled-task mechanism that carries a guest across reboots, the rule that credentials never outlive the phase that needs them, and Test-SILab.ps1. Use when writing or changing anything under powershell/, when the user mentions a bootstrap script, first-boot config, AD promotion, domain join, the OU tree, a baseline GPO, the health check, or PSScriptAnalyzer in this repo. Not for Windows PowerShell 5.1 language style, param blocks, error handling or the 5.1-versus-7 traps — the global `powershell` skill owns those, and this one assumes them. Not for how Terraform invokes these scripts — see terraform-proxmox.
---

# PowerShell conventions for the SI lab

The layer that turns three booted Windows VMs into a domain. The global `powershell`
skill owns how to write 5.1 correctly; this one owns the architecture those scripts have
to fit, which is unusual enough that following language style alone will produce something
that does not work here.

## Layout

Everything lives flat in `powershell/`. Three entry points, one per guest, plus a shared
module and a read-only health check:

| File | Role |
| --- | --- |
| `Bootstrap-DC01.ps1` | Domain controller: rename, address, promote the forest, OUs, groups, GPOs |
| `Bootstrap-SRV01.ps1` | Member server: rename, address, join into `Computers/Servers` |
| `Bootstrap-CL01.ps1` | Client: rename, address, join into `Computers/Workstations` |
| `SILab.psm1` | Logging, phase markers, scheduled-task register/unregister, idempotency guards |
| `Test-SILab.ps1` | Read-only verification of the whole domain against the design docs |
| `PSScriptAnalyzerSettings.psd1` | The rule set CI enforces |

Terraform uploads the **whole directory** to `C:/lab-provisioning/` and runs
`Bootstrap-<HOSTNAME>.ps1` from there. Import the module by path from that directory, never
from a system module path — it is never installed, only copied.

Three separate entry points, deliberately. There is no role parameter to branch on, because
a shared script would only be an `if`/`else` dispatching on hostname. Changing this shape
means changing Terraform that is already merged.

## Constraints from PLAN.md

- **The guest drives itself across reboots.** Terraform invokes one entry point and stops.
  Renaming a host reboots, and so does promoting a domain controller. Each phase writes its
  marker **before** the call that triggers the reboot, not after, or the resume lands in the
  wrong phase. A scheduled task registered on the first run continues the sequence on each
  boot and is removed when the last phase completes. Never solve a reboot by adding a second
  `remote-exec` to Terraform.
- **Credentials never outlive the phase that needs them.** Passwords arrive as command-line
  arguments and are gone after a reboot, and nothing may write them to the guest's disk.
  Order phases so every credential is consumed before the reboot that loses it. After
  promotion, the scheduled task runs as SYSTEM on a domain controller and already holds the
  directory rights to create OUs, groups and policies. A phase that needs a credential after
  a reboot is a design error — reorder it rather than adding a credential store.
- **Passwords arrive as plain strings, not `SecureString`.** Terraform passes command-line
  arguments, so the parameter cannot be a `SecureString`. Convert on the first line that
  touches it, and let it reach no log line, no transcript and no error message.
- **Windows PowerShell 5.1 only.** No PowerShell 7 is installed and none will be — see the
  decision in `PLAN.md`. The global `powershell` skill covers what that rules out.
- **The design documents are the spec.** `docs/ad-design.md` defines the forest, the OU
  tree, the groups and all three GPOs; `docs/network-design.md` defines every address. Never
  write a value that contradicts either — change the document first, in the same commit.

## Conventions

- Every phase is idempotent. Provisioning is a retry, never a hand-fix: a re-run finds some
  of its work already done and must treat that as success, not as an error to swallow.
- Log to a fixed path under `C:\ProgramData`. Phases run as SYSTEM after a reboot, so
  anything written to a user profile lands somewhere nobody will look.
- Every state-changing function declares `[CmdletBinding(SupportsShouldProcess)]`.
- `Test-SILab.ps1` is read-only — no `New-`, no `Set-`, nothing that changes state, so it is
  safe to run repeatedly against a live domain. Every check maps to a specific row in a
  design document, and it exits non-zero if any check fails so a runbook step can gate on it.
- DC01's computer object never moves out of the built-in `Domain Controllers` OU. Moving a
  domain controller out of it breaks the policies Microsoft links there.
- Members join **directly into** their target OU rather than joining and then moving, so a
  machine never sits briefly in the default `Computers` container outside GPO scope.
- A GPO's creation and its link are separate steps, so a re-run can repair a missing link
  without rebuilding the policy.

## Validation

Nothing here can be run — there is no host, and the development machine cannot stand in.
PSScriptAnalyzer and a careful read against the design documents are the only evidence this
layer is correct, which is weaker than every other layer in the repo. Write accordingly:
prefer the obvious construction over the clever one, since nothing will catch the
difference. The command CI runs is in `AGENTS.md`.

## Gotchas

<!-- Empty until the scripts exist (Milestone 6). Anything that costs more than an hour to
work out goes here, not in a commit message nobody rereads. -->
