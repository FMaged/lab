# SI Portfolio Lab

A small company network — Proxmox host, Windows Server 2025 and Windows 11 images, VMs,
Active Directory and a routed multi-VLAN network — built entirely as code and rebuildable
from this repo.

**No host exists yet and nothing here can be run locally.** The development machine is a
VMware guest with no nested virtualization and a full disk. Every layer is checked
statically in CI — that is the only feedback loop this project has. Do not propose testing
by running something; that option does not exist.

## Start here

- `PLAN.md` — goal, stack, and every decision with its reasoning. Read it before proposing
  anything architectural. If a decision there rejected an option, it stays rejected until
  the entry is replaced.
- `TASKS.md` — milestones and open work. Work comes from the current milestone only; later
  milestones are deliberately empty until the one before them lands.
- `docs/` — the design the code implements.

## Layout

| Path | What lives here |
| --- | --- |
| `packer/` | Windows Server 2025 and Windows 11 base image builds |
| `terraform/` | VM provisioning against Proxmox (bpg/proxmox) |
| `powershell/` | First-boot OS config, AD promotion, domain join, GPOs |
| `opnsense/` | Router and firewall config (browningluke/opnsense) |
| `docs/` | Network and AD design, hardware, conventions, runbook |
| `.github/workflows/` | The validation harness |

## Setup

Nothing is installed locally and nothing should be — the dev machine has about 1 GB free,
which is why CI is the harness (see the decision in `PLAN.md`). CI installs everything and
pins Terraform **1.16.1**, Packer **1.16.0** and PSScriptAnalyzer **1.25.0**. Provider and
plugin versions are pinned exactly in `terraform/versions.tf`, `opnsense/versions.tf` and
`packer/plugins.pkr.hcl`.

Never loosen a pin to `~>` — an unpinned constraint means a build can break with no change
to the code. Bumping one is a deliberate, single-purpose commit with the changelog read
first, especially for the pre-1.0 OPNsense provider.

## Commands

No build, no test, no run. CI validates and never applies, so it holds no credentials and
no repository secrets are configured — keep it that way. These are exactly what
`.github/workflows/validate.yml` runs, and what to run locally on the rare occasion a tool
is available:

| Layer | Command |
| --- | --- |
| `terraform/`, `opnsense/` | `terraform fmt -check -recursive`, then `terraform init -backend=false && terraform validate` |
| `packer/` | `packer fmt -check .`, then `packer init . && packer validate .` |
| `powershell/` | `Get-ChildItem -Path powershell -Recurse -Include *.ps1,*.psm1 \| Invoke-ScriptAnalyzer -Severity Error,Warning -Settings powershell/PSScriptAnalyzerSettings.psd1` |
| whole repo | gitleaks secret scan, lychee markdown link check — push and read the run |

Every commit stays fmt-clean and validate-clean. A red build is the only error message
this project gets.

## Code style

- `docs/network-design.md` is the single source of truth for every address, VLAN and
  subnet. `docs/ad-design.md` is the spec `powershell/` implements. Never hardcode a value
  that contradicts either — change the doc first, in the same commit.
- PowerShell is Windows PowerShell 5.1 only. The global `powershell` skill covers style;
  the rule on top of it here is that every script is idempotent — clones are provisioned by
  running them at first boot, and a failed run is retried, not hand-fixed.
- **The guest drives itself across reboots.** Terraform invokes one entry point per guest
  and stops. Renaming a host and promoting a domain controller both reboot, so each phase
  writes a marker before the call that triggers the reboot and a scheduled task resumes the
  next phase on boot. Never add a second `remote-exec` to Terraform to work around a
  reboot — see the decision in `PLAN.md`. Phases run as SYSTEM after a reboot, so log to
  `C:\ProgramData`, never a user profile.
- **Credentials never outlive the phase that needs them.** Terraform passes passwords as
  command-line arguments, which are gone after a reboot, and nothing may write them to the
  guest's disk. Order phases so every credential is consumed before the reboot that loses
  it — after promotion, SYSTEM on a domain controller already has the rights. A phase that
  needs a credential after a reboot is a design error; reorder it rather than adding a
  credential store.
- Terraform uploads all of `powershell/` to `C:/lab-provisioning/` and runs
  `Bootstrap-<HOSTNAME>.ps1` from there. Three entry points, one per guest, no role
  parameter. Changing that shape means changing merged Terraform.
- Per-layer conventions live in `.claude/skills/`: `terraform-proxmox`,
  `terraform-opnsense`, `packer-windows`, `github-actions-ci`. Read the one for the layer
  being touched.
- Docs are a deliverable. A layer is not done until its section of `docs/runbook.md` is
  filled in.

## Off-limits

- **No secret lands in git** — no passwords, no Proxmox API token, no tfvars. Secrets are
  env vars (`TF_VAR_*`, `PKR_VAR_*`, `PROXMOX_VE_*`, `OPNSENSE_API_*`) and gitignored local
  var files. PowerShell receives its secrets as inline parameters from Terraform's WinRM
  provisioner, never from a file on disk. See the decision in `PLAN.md`.
- Do not add repository secrets or credentials to CI. The secrets decision depends on CI
  having none; if that ever has to change, the decision gets revisited first.
- `.gitleaks.toml` allowlists exactly one string — the Packer build-time bootstrap
  password. Do not add a second entry to silence a finding; fix the finding.
- Never commit: `*.tfvars`, `*.pkrvars.hcl` (except `example.pkrvars.hcl`), `*.tfstate*`,
  `.terraform/`, `packer_cache/`, `*.env`.

## Gotchas

- Nothing here has ever been executed. Every design doc describes a network that has not
  been built — write it that way, plainly, rather than as if it runs.
- `Invoke-ScriptAnalyzer` has no `-Include` parameter of its own — that one belongs to
  `Get-ChildItem`. Filter the file list first, or `PSScriptAnalyzerSettings.psd1` gets
  swept up as a file to analyze.
- The OPNsense provider is pre-1.0 with no stability guarantee. Check a resource exists in
  `0.26.0` specifically, not in the latest docs.
- Both Packer images are German (de-DE) throughout, so Windows errors come back in German.
  That was an accepted cost, not an oversight.

## Working agreement

- **A milestone is a branch, a task is a commit, a milestone is one PR.** Branch from
  `main` when the milestone's first task starts, commit each task's diff on its own, open
  one PR for the branch. Branch and commit format: `docs/conventions.md`.
- Check tasks off in `TASKS.md` as they finish. If the work went differently than the task
  said, one line under `Notes:`.
- A new decision goes in `PLAN.md` as a decision entry — not in a commit message.
- Do not add a dependency, service or abstraction that no open task needs. Out of scope on
  purpose: HA, clustering, cloud/hybrid identity, monitoring, sysprep.
