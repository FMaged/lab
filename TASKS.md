# Tasks

<!--
[ ] open   [x] done   [~] dropped (add a one-line reason)
Tasks are numbered 1, 2, 3... per milestone; sub-tasks are <task>.1, <task>.2.
Do not rewrite a task after work on it started. Add new tasks at the end — a new
task gets the next number; earlier numbers never change.
If the work went differently than planned, write it under Notes:
-->

## Milestone 1: The whole build is designed and readable from the repo alone

No Proxmox hardware yet, so this milestone produces the design and the entry point.
Someone who opens the repo can see what gets built, on what addresses, in what order.

1. [x] Initialize the repository
   **What:** a git repo with a .gitignore covering Terraform state/plan files, Packer output
   directories and tfvars, plus a LICENSE and a repo description.
   **Why:** every other task writes files into this repo from here on, and secrets (tfvars)
   and generated build artifacts must never land in git — that has to be true from the
   first commit, not retrofitted later.
   **How:** git init; .gitignore entries for terraform.tfstate*, .terraform/, Packer output
   dirs and *.auto.tfvars; add a LICENSE; set the repo description.

   1.1. [x] git init, .gitignore for Terraform state, Packer output and tfvars
   1.2. [x] LICENSE and a repo description

   Notes: main branch, MIT license. Repo description deferred — no GitHub remote yet;
   set it when the repo is first pushed.

2. [x] Create the directory layout with a stub README in each layer
   **What:** top-level folders packer/, terraform/, powershell/, opnsense/, docs/, each with
   a short README stating what will live there.
   **Why:** the repo layout is the first thing a reviewer sees before any code exists — it
   has to communicate the four-layer architecture on its own.
   **How:** mkdir the five directories, drop a one-paragraph README.md in each.

   2.1. [x] packer/, terraform/, powershell/, opnsense/, docs/

   Notes:

3. [x] Write docs/network-design.md
   **What:** VLAN list and purpose, subnet and gateway per VLAN, a static address table for
   DC01/SRV01/firewall interfaces, and DHCP scopes/reservations/options with DNS
   forwarders.
   **Why:** this is the single source of truth every other layer has to agree with —
   Terraform's static IPs, the OPNsense config, and the PowerShell provisioning all read
   from these addresses, so it has to exist before any of them are written.
   **How:** one markdown table per VLAN (purpose, subnet, gateway), one static-address
   table, one section for DHCP scopes/reservations/options and DNS forwarders.

   3.1. [x] VLAN list and purpose, subnet per VLAN, gateway addresses
   3.2. [x] Static address table for DC01, SRV01 and the firewall interfaces
   3.3. [x] DHCP scopes, reservations and options, DNS forwarders

   Notes: 3 VLANs (10 Mgmt / 20 Servers / 30 Clients), 10.10.x.0/24, chosen to sit
   clear of the existing 192.168.1.0/24 home network per user. DHCP only on the
   Clients VLAN — Mgmt and Servers are static and listed in the table.

4. [x] Write docs/ad-design.md
   **What:** forest and domain name, functional level, site name, OU structure with the
   reasoning behind its shape, groups, and the three baseline GPOs with what each one
   enforces.
   **Why:** Milestone 5's PowerShell promotes DC01 and applies this structure directly —
   writing the design now means that script implements a spec instead of ad-hoc
   decisions made while coding.
   **How:** one section per topic; OU structure gets a short paragraph justifying its
   shape; each GPO gets a one-line "what it enforces and why".

   4.1. [x] Forest and domain, functional level, site name
   4.2. [x] OU structure and the reasoning behind its shape
   4.3. [x] Groups and the three baseline GPOs, each with what it enforces and why

   Notes: functional level 2025 (no legacy DC to support). Workstation GPO's logon
   banner chosen deliberately as the visible proof-point for Milestone 6.

5. [x] Draw the network diagram as Mermaid in docs/
   **What:** a Mermaid diagram showing the VLANs, the firewall, and where DC01/SRV01/CL01
   sit on the network.
   **Why:** the README links to one diagram as the fastest way for a reviewer to grasp the
   topology — the address tables in network-design.md don't give that at a glance.
   **How:** a Mermaid graph/flowchart block in docs/, matching the addresses and VLANs
   already written in network-design.md.

   Notes:

6. [x] Write docs/hardware.md — the Proxmox host
   **What:** the target Proxmox host spec and the UEFI/virtualization/NIC prerequisites to
   verify before install.
   **Why:** Milestone 2 needs the hardware bought and installed correctly on the first
   attempt — there's no lab access yet to iterate on a wrong spec.
   **How:** list CPU/RAM/disk/NIC targets and why they're enough for four guests, plus a
   pre-install checklist (VT-x/AMD-V enabled, UEFI boot, NIC passthrough support).

   6.1. [x] Target spec and why it is enough for four guests
   6.2. [x] UEFI, virtualization and NIC prerequisites to check before install

   Notes: documented both single-NIC and dual-NIC trunk layouts since the actual host
   isn't bought yet — narrow to one once hardware is chosen.

7. [x] Write docs/conventions.md
   **What:** the VM and hostname naming scheme, Terraform resource/variable naming, VM
   tags, and branch/commit conventions.
   **Why:** Terraform, PowerShell and git history all need to follow one scheme
   consistently from the first resource — renaming later means touching every layer
   that references it.
   **How:** short reference tables for hostname pattern, Terraform naming pattern and tag
   list, plus a pointer to the git-conventions skill for branch/commit format.

   7.1. [x] VM and hostname scheme, Terraform resource and variable naming, VM tags
   7.2. [x] Branch and commit conventions

   Notes: branch/commit section just points at the global git-conventions skill and
   fixes no-ref as the default (solo project, no ticket tracker).

8. [x] Write docs/runbook.md as a skeleton
   **What:** bare metal to a working domain, ordered, with a placeholder section per layer
   to fill in as each milestone lands.
   **Why:** this is the proof that the whole lab "rebuilds from zero in one documented
   pass" (Milestone 7) — it has to exist from the start so each milestone adds to it as
   it's built, instead of being reconstructed from memory at the end.
   **How:** one heading per milestone in build order, each with a one-line placeholder.

   Notes:

9. [x] Write the top-level README.md
   **What:** what this lab demonstrates, the architecture in one diagram, and where to
   start reading.
   **Why:** per the goal in PLAN.md, this is the page the reviewer actually opens — success
   is them understanding what was built and why within five minutes of landing here.
   **How:** short intro, embed/link the Mermaid diagram, links to docs/*.md in reading
   order, link to the runbook.

   Notes:

10. [x] SPIKE: how does OPNsense get configured as code (max 2h)
    **Why:** Milestone 4 needs a repeatable, version-controlled way to apply VLANs,
    interfaces, DHCP and firewall rules — picking the wrong mechanism now means redoing
    the whole opnsense/ layer later.
    **How:** compare config.xml import against the REST API for coverage of VLANs,
    interfaces, DHCP and firewall rules; note any plugin dependencies.
    Output: one decision entry in PLAN.md
    Notes: researched live — the REST API has full coverage, and a community Terraform
    provider (browningluke/opnsense) wraps it well enough to keep OPNsense under the
    same `terraform apply` as everything else. Decision + accepted risk in PLAN.md.

11. [x] SPIKE: how do secrets reach Packer, Terraform and PowerShell (max 2h)
    **Why:** the domain administrator password, the Proxmox API token and the local admin
    password each need to reach a different tool, and none of them can land in git —
    the approach has to work for all three or the layers won't agree.
    **How:** compare .gitignored tfvars + env vars against a local secrets file and a
    secrets manager; check what Packer, Terraform and PowerShell can each consume
    natively.
    Output: one decision entry in PLAN.md
    Notes: env vars + gitignored tfvars/pkrvars cover Packer and Terraform natively;
    PowerShell has no equivalent since it runs in-guest, so Terraform's WinRM
    provisioner hands it secrets as sensitive inline parameters. Decision in PLAN.md.

<!--
PLAN REVISION — 2026-09-11
No Proxmox host exists and there may never be one, and the development machine cannot
stand in for it (VMware guest, no nested virtualization, full disk). The old Milestone 2
"Proxmox host is installed and reachable as an automation target" is therefore dropped as
a prerequisite and folded into the optional proof run at the end. Milestones 3, 4 and 5
keep their numbers and their subjects — the project skills reference them. What changed is
that each one now ends at "validated in CI", not "applied to a host".
See the execution status and CI decisions in PLAN.md.
-->

## Milestone 2: Every layer validates in CI on every push, and the repo is public

The only feedback loop this project has. Nothing can be run, so the harness that proves
the code holds together has to exist before the code does — otherwise three layers get
written with no way to tell whether any of them is even syntactically sound.

1. [x] Create the public GitHub repository and push
   **What:** a public repo with the Milestone 1 work in it, a description, topics, and
   `main` tracking the remote.
   **Why:** PLAN.md makes the public repo the deliverable — the link on a job
   application. Nothing in this milestone can be tested until Actions has somewhere to
   run, and task 1.2 left the repo description open pending exactly this.
   **How:** `gh repo create` as public, push `main`, set the description and topics
   (proxmox, terraform, packer, active-directory, windows-server, iac).

   Notes: user created github.com/FMaged/lab and pushed `main` directly (no `gh` CLI
   or token available in this environment). Confirmed public via the anonymous
   GitHub API. Description and topics are still unset — outstanding, needs the
   GitHub UI or a token, neither available here.

2. [x] Add pinned provider and plugin skeletons so validation has real input
   **What:** `terraform/versions.tf`, `opnsense/versions.tf` and `packer/plugins.pkr.hcl`,
   each declaring its provider or plugin at an exact pinned version and nothing else.
   **Why:** a validation job with no files to check is green for the wrong reason. These
   three files also settle the version pinning the OPNsense decision in PLAN.md
   explicitly requires, before any resource is written against a version that might move.
   **How:** `required_providers` for bpg/proxmox and browningluke/opnsense, and
   `required_plugins` for the Proxmox Packer plugin. Exact `=` constraints, never `~>`.
   Record each chosen version and the date in the file as a comment.

   Notes: versions checked live — bpg/proxmox 0.112.0, browningluke/opnsense 0.26.0,
   hashicorp/proxmox Packer plugin 1.2.3, all current as of 2026-09-11.

3. [x] CI job: Terraform formatting and validation for both roots
   **What:** a GitHub Actions job running `terraform fmt -check -recursive` and
   `terraform init -backend=false && terraform validate` in `terraform/` and `opnsense/`.
   **Why:** these two roots will hold most of the project's code, and `validate` is the
   only thing that will ever catch a bad resource argument, since nothing can be applied.
   **How:** `.github/workflows/validate.yml`, matrix over the two directories,
   `hashicorp/setup-terraform`. Backend disabled so init needs no Proxmox credentials.

   Notes: pinned terraform_version 1.16.1 in setup-terraform for determinism.

4. [x] CI job: Packer formatting and validation
   **What:** `packer fmt -check` and `packer init` plus `packer validate` over `packer/`.
   **Why:** the image build is the layer with the longest feedback loop even when
   hardware exists, so catching a malformed template statically is worth the most here.
   **How:** same workflow, `hashicorp/setup-packer`. `packer validate` needs a build
   block, which does not exist until Milestone 3 — gate the validate step on one being
   present so the job is honest rather than skipped silently.

   Notes: gate checks for any *.pkr.hcl besides plugins.pkr.hcl and prints an
   explicit ::notice:: instead of a silent pass when none exists yet.

5. [x] CI job: PSScriptAnalyzer over powershell/
   **What:** a job running PSScriptAnalyzer across `powershell/`, failing on Error and
   Warning severities.
   **Why:** the PowerShell is the one layer with no compiler and no validator of its own,
   and it is the layer that will run unattended at first boot with nobody watching. Static
   analysis is the only safety net it gets before a proof run.
   **How:** `Invoke-ScriptAnalyzer -Path powershell/ -Recurse -Severity Error,Warning`.
   Settings file pinning the rules, so a new analyzer release cannot turn the build red on
   its own.

   Notes: workflow installs PSScriptAnalyzer -RequiredVersion 1.25.0 explicitly, plus
   powershell/PSScriptAnalyzerSettings.psd1 pinning severities. First real push (2026-
   09-11) failed here twice — a self-scan of the settings file, then a fix attempt that
   passed -Include to Invoke-ScriptAnalyzer, which doesn't have that parameter (it's
   Get-ChildItem's). Fixed by filtering with Get-ChildItem and piping into
   Invoke-ScriptAnalyzer. Full story in the github-actions-ci skill's Gotchas.

6. [x] CI job: secret scanning on every push
   **What:** gitleaks over the full history and every new commit, failing the build on a
   hit.
   **Why:** PLAN.md's secrets decision says no credential ever lands in git, and the repo
   is public, so that rule needs a machine enforcing it rather than discipline. A leaked
   Proxmox token in a public portfolio repo is the single worst outcome available here.
   **How:** the gitleaks action in the same workflow, scanning full history on push to
   `main`. Confirm `.gitignore` already covers tfvars and pkrvars — it does — and that
   the scan would still catch a file committed with `-f`.

   Notes: gitleaks/gitleaks-action@v2 with fetch-depth 0; free for public repos, no
   license secret needed. Failed on the first real push (2026-09-11) — v2 is being
   retired ahead of GitHub's 2026-09-16 Node 20 removal. Bumped to v3, same inputs.

7. [x] CI job: documentation link check
   **What:** a link checker over every markdown file, failing on a dead relative link.
   **Why:** docs are a deliverable per PLAN.md, the README is the reviewer's entry point,
   and it links out to seven files. A broken link there is the cheapest possible bad
   impression.
   **How:** lychee or markdown-link-check over `**/*.md`, relative links only, external
   URLs excluded so a third-party outage cannot fail the build.

   Notes: lycheeverse/lychee-action@v2, excludes any http(s) URL by regex so only
   relative repo links are checked.

8. [x] Prove the harness actually fails
   **What:** a throwaway branch that breaks each check in turn — bad HCL, an unformatted
   file, a PowerShell analyzer violation, a fake credential, a dead link — confirming each
   job goes red, then deleted without merging.
   **Why:** an untested test harness is worth nothing, and this one is the project's only
   evidence of correctness. A job that is silently skipping or passing on an empty
   directory looks identical to a working one until the moment it matters.
   **How:** one commit per broken check on a branch, screenshot or note each red run, then
   delete the branch. Record in the Notes which check caught what.

   Notes: branch test/no-ref/prove-ci-catches-failures, opened as a PR (push alone
   doesn't trigger `on: push: branches: [main]` — needed the pull_request event) and
   closed by deleting the branch, never merged. One combined commit broke all six
   checks at once rather than one commit each — jobs run independently in parallel,
   so each failure is still unambiguously attributable to its own defect. Final run
   (github.com/FMaged/lab/actions/runs/34633917750): all 6 jobs red at the expected
   step — terraform fmt, terraform validate (opnsense), packer validate,
   PSScriptAnalyzer, gitleaks, Lychee link check.
   Two real bugs surfaced by the exercise itself, both fixed on main:
   - terraform's matrix had default `fail-fast: true`, so the opnsense job got
     cancelled instead of genuinely failing once the sibling terraform job failed —
     added `fail-fast: false` so one directory's break can never hide another's.
   - the first secret-scan test used AWS's own AKIAIOSFODNN7EXAMPLE key, which
     gitleaks allowlists by design (it's in thousands of docs) — gitleaks correctly
     did not flag it. Swapped to a fake, non-allowlisted AWS-shaped key to actually
     exercise the rule.
   packer's fmt violation was tested and confirmed separately in the first attempt,
   then removed so validate wasn't shadowed by an earlier failing step in the same
   job — both are proven, just not in the same run.

9. [x] Add the CI badge and an execution status section to README.md
   **What:** the workflow status badge at the top, and a short section stating exactly
   what is validated and what has never been run on real hardware.
   **Why:** PLAN.md requires the execution status to be stated plainly. The badge and that
   paragraph together are what stop a reviewer from either over-reading the repo as a
   running system or dismissing it as untested.
   **How:** badge from the Actions workflow, then a short section listing what CI checks
   and one sentence saying the lab has not yet been applied to a host. Keep the wording
   ready to update when the proof run lands.

   Notes: replaced the old one-line Status section with "Execution status" — a bold
   opening claim, the CI table from CLAUDE.md's Validation section, and an explicit
   line that green CI proves the code is well-formed, not that anything booted.
   Points at Milestone 8 as where that proof would come from.

   Notes:

10. [x] Record the CI contract in CLAUDE.md and docs/conventions.md
    **What:** the rule that every layer must stay fmt-clean and validate-clean, that CI
    holds no secrets, and the command each check runs.
    **Why:** Milestones 3 to 6 are written against this harness. Whoever writes that code
    needs to know the checks exist and what they enforce, without reading the workflow
    file to find out.
    **How:** a short Validation section in CLAUDE.md with the commands; the conventions
    doc gets the formatting and pinning rules. Both stay short — CLAUDE.md is loaded every
    session.

    Notes: CLAUDE.md's Validation section landed earlier in the plan-revision commit;
    this task added the matching "Formatting and pinning" section to
    docs/conventions.md.

## Milestone 3: Packer defines the Windows Server 2025 and Windows 11 templates

Two templates every later layer clones from: a Windows Server 2025 Desktop Experience
image for DC01 and SRV01, and a Windows 11 image for CL01. Both German, both with VirtIO
drivers and WinRM, neither generalized. The milestone ends when `packer validate` runs
green in CI on real build blocks — not when an image exists, because no host exists to
build one on.

1. [x] SPIKE: what does a Windows 11 unattended install actually require now (max 2h)
   **Why:** task 5 cannot be written without this. Windows 11 setup enforces TPM 2.0 and
   Secure Boot, and the local-account path through OOBE has moved more than once across
   releases — the `BypassNRO` route in particular stopped working in a recent build.
   Guessing here produces an answer file that hangs at a screen nobody can see, and with
   no host to test on that error would sit undetected until the proof run.
   **How:** confirm against current Microsoft documentation which `oobeSystem` settings
   create a local account without a Microsoft account, whether the hardware checks are
   satisfied by giving the VM a real TPM and Secure Boot rather than registry bypasses,
   and which image index the German ISO exposes for Windows 11 Pro.
   Output: one decision entry in PLAN.md
   Notes: researched live — BypassNRO is a red herring for a fully unattended build,
   since it works around an interactive OOBE screen the answer file never shows. The
   real mechanism is UserAccounts/LocalAccounts + HideOnlineAccountScreens in
   oobeSystem, same as MDT/Autopilot use, confirmed still working into 2026. No
   hardware-check bypass keys needed since the VM gets a real TPM/Secure Boot.
   Also confirmed packer-plugin-proxmox 1.2.3 (pinned) supports tpm_config and
   efi_config/pre_enrolled_keys — added in 1.2.0. Decision in PLAN.md, including the
   one unverified detail (exact German image-index name) left for the proof run.

2. [x] Add template naming and ISO conventions to docs/conventions.md
   **What:** the name each template gets in Proxmox, where installation and VirtIO ISOs
   live on the host, and the rule for what happens when an image is rebuilt.
   **Why:** the `packer-windows` skill explicitly defers naming to `docs/conventions.md`,
   and that file has no template section yet. Milestone 5 clones these templates by name,
   so the name is an interface between two layers and cannot be invented twice.
   **How:** extend the existing conventions file with a template table, an ISO datastore
   path convention, and the "a changed image is a new template, never an edit" rule the
   skill already states — the conventions file is where it belongs.

   Notes: tpl-winsrv2025-de-v1 / tpl-win11-de-v1, explicit -vN suffix mandatory.
   Template VMIDs reserved to 9000-9099, clear of any future guest VMID range. ISO
   filenames are version-pinned too, no "latest" alias.

3. [x] Write the shared Packer variables and a committed example var file
   **What:** `packer/variables.pkr.hcl` declaring Proxmox connection and node, the
   datastores, ISO paths and checksums, and the local administrator password as
   `sensitive`; plus a committed `packer/example.pkrvars.hcl` with placeholder values.
   **Why:** the secrets decision in PLAN.md routes real values through `PKR_VAR_*` and
   keeps `*.pkrvars.hcl` out of git, which leaves a reader no way to know what to set. A
   committed example file is how that gap gets closed without shipping a credential.
   **How:** one `variable` block per input with a description and type. Mark the password
   `sensitive = true`. Confirm `.gitignore` already excludes `*.pkrvars.hcl` and that the
   example filename does not match the ignore pattern, or it will silently never commit.

   Notes: the ignore-pattern trap was real — `*.pkrvars.hcl` did swallow
   example.pkrvars.hcl, needed `!example.pkrvars.hcl` right after it, confirmed with
   `git add` actually staging the file. Also discovered `packer validate` (unlike
   `terraform validate`) hard-fails on any variable with no default ("Unset
   variable") — every variable here has one, including the sensitive ones (empty
   string / "none" for checksums), so CI can validate with zero real secrets.

4. [x] Write the Windows Server 2025 answer file
   **What:** `packer/files/autounattend-server.xml` — German locale throughout, UEFI/GPT
   partitioning, Desktop Experience image selection, the local administrator, and WinRM
   enabled on first boot.
   **Why:** this is the file that makes the install unattended, and per the skill it is
   allowed to do only four things. Everything else is a provisioner, so keeping it narrow
   is what stops the image from accumulating machine-specific state.
   **How:** `Microsoft-Windows-International-Core-WinPE` set to de-DE for UI, input,
   system and user locale in the `windowsPE` pass. GPT layout with an EFI system
   partition, MSR and Windows partition. Select the Desktop Experience image name from
   the German ISO, not by number. VirtIO storage driver path added so
   Setup can see the disk. WinRM enabled from a `FirstLogonCommands` entry.

   4.1. [x] Locale, keyboard and timezone, all de-DE
   4.2. [x] UEFI/GPT disk layout and Desktop Experience image selection
   4.3. [x] Local administrator and WinRM enablement

   Notes: image name "Windows Server 2025 SERVERSTANDARD" — Desktop Experience is
   selected by name, not index, but the exact string is still unverified against a
   real German ISO (same residual-unknown caveat as the Windows 11 SPIKE). vioscsi
   driver path confirmed real (2k25\amd64, matches the virtio-scsi-single controller
   task 6 will use) rather than assumed. Administrator password in the XML is a
   fixed, non-secret build-time bootstrap value, not the real `local_admin_password`
   — a provisioner rotates it to the real one as the *last* step of the build
   (task 8), after every other provisioner that needs WinRM has already run;
   rotating it earlier risks breaking Packer's own WinRM session for the rest of
   the build. So the real secret never touches this file. This wasn't spelled out
   in the task's How; adding
   it here since the plan didn't say how the real password reaches the image at all.

5. [x] Write the Windows 11 answer file
   **What:** `packer/files/autounattend-client.xml` — the same shape as the server answer
   file, plus whatever the spike in task 1 determined is needed for a local account and
   the hardware checks.
   **Why:** CL01 is the machine that demonstrates domain join and a GPO actually applying,
   so this is the answer file the visible proof depends on.
   **How:** start from the server answer file, change the image selection to Windows 11
   Pro, and apply the spike's findings. Do not copy registry bypasses found in forum posts
   without understanding them — the VM gets a real TPM and Secure Boot in task 7, which is
   the supported path.

   Notes: zero hardware-check bypass keys, as the SPIKE concluded. One real
   structural difference from the server file beyond ISO/driver paths:
   UserAccounts/LocalAccounts instead of AdministratorPassword, since client SKUs
   ship the built-in Administrator disabled — this is the SPIKE's actual mechanism,
   not BypassNRO. vioscsi driver path is w11\amd64, not 2k25\amd64.

6. [x] Write the Windows Server 2025 source and build block
   **What:** `packer/windows-server-2025.pkr.hcl` — a `proxmox-iso` source producing a
   Proxmox VM template, with the installation ISO and the VirtIO driver ISO both attached.
   **Why:** this is the artifact DC01 and SRV01 clone from, and per the skill the build is
   finished the moment Packer can reach WinRM.
   **How:** `q35` machine type with OVMF firmware and an EFI disk, `virtio-scsi-single`
   controller, a VirtIO network adapter, and the answer file delivered as an additional
   ISO. WinRM communicator with a generous timeout, since a German ISO installing updates
   is slow. Tags and template name from `docs/conventions.md`.

   Notes: vm_id 9000, matching the 9000-9099 template range. This file is the
   `source` block only, per its own What — the `build` block combining this with
   the Windows 11 source and the shared provisioner chain lands in a new
   packer/build.pkr.hcl in task 8, since no file was named for it. efi_config
   present but pre_enrolled_keys = false — Secure Boot is task 7's addition, not
   Server's requirement.

7. [x] Write the Windows 11 source and build block with TPM and Secure Boot
   **What:** `packer/windows-11.pkr.hcl` — the client source, adding a TPM 2.0 device and
   Secure Boot to the firmware configuration.
   **Why:** Windows 11 Setup refuses to install without both, and giving the VM real
   virtual hardware is the supported way past that rather than disabling the checks.
   **How:** same shape as task 6, plus the plugin's TPM configuration block pointing at a
   storage pool for TPM state, and Secure Boot enabled on the EFI disk. Confirm the pinned
   plugin version actually supports the TPM block before relying on it — if it does not,
   that is a version bump commit of its own, not a workaround.

   Notes: vm_id 9001. tpm_config and efi_config's pre_enrolled_keys confirmed
   supported by the pinned plugin 1.2.3 (added in 1.2.0) during the SPIKE, so no
   surprise here. Build block combining both sources still pending — task 8.

8. [x] Write the shared provisioners
   **What:** the provisioner chain both builds run — QEMU guest agent install, Windows
   Updates, and a final cleanup pass.
   **Why:** PLAN.md specifies a patched base image, and the guest agent is what lets
   Proxmox and Terraform see a VM's address and shut it down cleanly. Without it Milestone
   5 has no reliable way to tell when a clone has finished booting.
   **How:** a Windows Update provisioner needs a second Packer plugin, so pin it exactly in
   `plugins.pkr.hcl` alongside the Proxmox one and record why it is there. Every
   provisioner must be re-runnable per the skill. No sysprep in the cleanup step — that is
   a standing decision in PLAN.md, so say so in a comment where someone would expect one.

   8.1. [x] QEMU guest agent
   8.2. [x] Windows Updates, with the extra plugin pinned
   8.3. [x] Cleanup, explicitly without sysprep

   Notes: rgl/windows-update 0.18.4 pinned in plugins.pkr.hcl. Added a 4th step
   beyond the three listed — rotating the bootstrap password to the real
   local_admin_password — since nothing in Milestone 3 otherwise specified how the
   real secret reaches the image; it has to run last, after every WinRM-dependent
   step, not first (see the correction on tasks 4/5). Guest-tools install and the
   password rotation are real .ps1 files in packer/files/, not inline HCL strings,
   since the guest-tools step needs real logic (dynamic CD-ROM discovery) that
   doesn't fit cleanly inline. The build block combining both sources lives in the
   new packer/build.pkr.hcl, per the note on task 6.

9. [x] Turn on packer validate in CI and get it green
   **What:** remove the Milestone 2 gate in `.github/workflows/validate.yml` that skips
   `packer validate` when no build template exists, so both builds are validated on every
   push.
   **Why:** that gate was written to be honest while `packer/` held only a plugin pin. Once
   real build blocks exist it stops protecting anything and starts hiding regressions in
   the one layer with no other feedback available.
   **How:** delete the conditional and its notice, leaving a plain `packer validate .`.
   Confirm the job actually goes red for a malformed block before trusting it, the same way
   Milestone 2 task 8 proved the rest of the harness.

   Notes: gate removed, and the "goes red for a real problem" proof happened
   organically rather than as a staged exercise — the very first real run against
   tasks 6-8's actual HCL failed on `packer fmt` (a one-space alignment bug in
   `tags` in both source files, found by temporarily borrowing `terraform fmt` —
   see the new convention in the github-actions-ci skill) and on `gitleaks`
   (flagged the documented-non-secret bootstrap password, fixed with a scoped
   `.gitleaks.toml` allowlist). Stronger evidence than a synthetic malformed-block
   test, since these were genuine mistakes in the real templates, not manufactured
   ones. `terraform`/`opnsense`/`PSScriptAnalyzer`/link-check all stayed green
   throughout, confirming the failures were correctly attributed to `packer` only.

   Notes:

10. [x] Fill in the image build section of docs/runbook.md
    **What:** the ordered steps to produce both templates on a real host — upload the ISOs,
    set the `PKR_VAR_*` values, run each build, confirm the templates appear.
    **Why:** CLAUDE.md makes a layer unfinished until its runbook section is written, and
    this section is what a proof run would actually be executed from. Writing it now, while
    the build blocks are fresh, is the difference between a runbook and a reconstruction.
    **How:** fill the existing placeholder section. Mark clearly that these steps have never
    been executed, consistent with the execution status decision in PLAN.md.

    Notes: 6 steps — upload ISOs, fill the real var file, `packer init && packer
    build .` (one invocation builds both templates, since they share one build
    block), what to check if it hangs before WinRM (the three residual unknowns
    from this milestone: drive letters, image-index names, password drift),
    confirm both templates land at their reserved VMIDs, and the never-overwrite
    rebuild rule. Opens with an explicit "never executed" per the execution status
    decision.

## Milestone 4: OPNsense routes the lab VLANs

The firewall becomes a VM defined in code, a documented manual install, and a rule set
under `terraform apply`. This milestone also scaffolds the `terraform/` root, because the
OPNsense VM is the first resource to land in it. Ends when both Terraform roots validate
green in CI against real resources — no host exists to apply them to.

1. [x] SPIKE: where exactly does the manual/code boundary fall (max 2h)
   **Why:** the bootstrap decision in PLAN.md fixes that there is a manual half, but not
   its size. Interface assignment and interface addressing are core OPNsense settings and
   may not be exposed as provider resources at all, while VLAN creation, DHCP and rules
   almost certainly are. Tasks 5, 7, 8 and 9 all change shape depending on the answer, and
   guessing means writing resources for a provider version that has no such resource.
   **How:** read the browningluke/opnsense 0.26.0 resource list against the pinned
   version, not the latest docs, and sort every item in `docs/network-design.md` into
   manual or code. Note anything the provider claims to support but marks experimental.
   Output: one decision entry in PLAN.md, and the split that task 5 writes down
   Notes: checked the actual v0.26.0 docs/resources listing (47 files) rather than the
   provider's latest docs. Confirmed: opnsense_interfaces_vlan (tag/parent/device) plus
   full Kea DHCP and firewall/NAT/alias coverage exist; nothing assigns a raw interface
   to a logical slot or sets its IP (interfaces_vip is CARP-style VIPs, not primary
   addressing) — that stays manual, done *after* Terraform creates the VLAN devices, not
   before. Decision in PLAN.md.

2. [x] Write the firewall policy into docs/network-design.md
   **What:** a rule table — source, destination, service, and the reason the rule exists —
   plus the default-deny stance and the outbound NAT behaviour.
   **Why:** PLAN.md requires least privilege with a reason on every rule, and the
   `terraform-opnsense` skill forbids inventing network facts in code. Without this table
   `firewall.tf` becomes the spec, which is exactly backwards and impossible to review.
   **How:** one row per rule. Work out what a domain member genuinely needs to reach a
   domain controller — DNS, Kerberos, LDAP, SMB and time — and list those explicitly
   rather than opening the whole Servers VLAN. State that Management is reachable from no
   other VLAN.
   **Accept:** every row has source, destination, service and a reason. Management appears
   as a destination in zero rules. Clients reach DC01 on DNS, Kerberos, LDAP, SMB and time
   and on nothing else. Default-deny and the outbound NAT behaviour are each stated.

   2.1. [x] Client-to-DC service rules, named per service
   2.2. [x] Management isolation and the default-deny statement
   2.3. [x] Outbound internet access per VLAN, and the NAT rule

   Notes: 5 inter-VLAN rules (Clients->DC01 only), 5 outbound rules (one set per
   VLAN, Clients get no direct DNS/NTP since both go through DC01/AD instead), one
   NAT statement covering all three subnets. SRV01 isn't a destination anywhere
   yet — nothing in the current topology needs to reach it directly.

3. [x] Assign guest VMIDs in docs/conventions.md
   **What:** a fixed VMID for OPNsense, DC01, SRV01 and CL01, in a range clear of the
   `9000`–`9099` template block.
   **Why:** the `terraform-proxmox` skill requires every VM to carry an explicit `vm_id`
   taken from the design docs so a rebuild lands on the same ID, but no document assigns
   guest VMIDs yet. The OPNsense VM in task 4 is the first one that needs one.
   **How:** extend the existing conventions file next to the template VMID rule. Keep the
   numbering related to the VLAN layout so the ID says something about the host.
   **Accept:** four VMIDs listed — OPNsense, DC01, SRV01, CL01 — none inside `9000`–`9099`,
   none repeated, each one readable back to its VLAN.

   Notes: `<VLAN ID> x 10 + sequence>` — OPNsense 101, DC01 201, SRV01 202, CL01
   301. OPNsense placed on Management (10) since that's the one address it has
   that isn't a gateway for something, per network-design.md's address table.

4. [x] Scaffold the terraform/ root
   **What:** `providers.tf`, `variables.tf` and a committed `example.tfvars` for the
   bpg/proxmox root, which currently holds only a version pin.
   **Why:** the OPNsense VM lands here per the decision in PLAN.md, and Milestone 5 adds
   three more guests to the same root. Getting the provider configuration and the variable
   shape right once means Milestone 5 only adds resources.
   **How:** provider configured from `PROXMOX_VE_*` environment variables per the secrets
   decision — no endpoint or token in a committed file. Variables for node name,
   datastores and the VLAN IDs, every secret marked `sensitive = true`. Naming follows
   `docs/conventions.md`.
   **Accept:** `terraform init -backend=false && terraform validate` is green in
   `terraform/`. No endpoint, token or password literal in any committed file. Every secret
   variable carries `sensitive = true`. `example.tfvars` lists every variable with a
   placeholder value.

   Notes: confirmed real with a locally installed terraform (fmt clean, init and
   validate both green). No `sensitive = true` anywhere — this root's variables
   (node, two datastores, three VLAN IDs) are all genuinely non-secret; the
   `provider` block has an empty body and picks up `PROXMOX_VE_ENDPOINT` /
   `PROXMOX_VE_API_TOKEN` natively, so there's no endpoint/token variable to mark
   sensitive at all. Guest-level secrets (WinRM passwords) arrive in Milestone 5
   with the guests that actually need them. `.terraform.lock.hcl` committed too,
   on Terraform's own recommendation — same pinning discipline as everything
   else. Added `!example.tfvars` to `.gitignore`, the same trap `*.pkrvars.hcl`
   had.

   Notes:

5. [x] Write terraform/vm-opnsense.tf
   **What:** the firewall VM — two NICs, one on the WAN bridge and one on the VLAN trunk,
   with disk, CPU and memory from `docs/hardware.md`, its VMID from task 3 and the `lab`
   and `role-firewall` tags.
   **Why:** the rebuild-from-repo claim only holds if the firewall is in code, and this is
   the VM every other VM depends on for a gateway.
   **How:** the trunk NIC carries VLANs 10, 20 and 30 tagged, so it is the one interface
   in the project that must not set a single `vlan_id` — note why in a comment, since the
   skill otherwise treats an untagged NIC as a bug. Boot from the OPNsense ISO rather than
   cloning a template; this guest has no Packer image.
   **Accept:** `terraform validate` green. Two NICs, the trunk one with no `vlan_id` and a
   comment saying why. `vm_id` matches what task 3 assigned. CPU, memory and disk match
   `docs/hardware.md`. Tags `lab` and `role-firewall` both present.

   Notes: fmt+validate both real and green (terraform CLI installed locally now).
   Added two variables beyond task 4's set — proxmox_bridge_wan/_trunk — since
   docs/hardware.md never named actual bridge names (it only describes the two
   viable NIC layouts), so they're configurable rather than hardcoded. Set
   agent.enabled = false deliberately: OPNsense/FreeBSD has no qemu-guest-agent
   installed by default, so leaving it on would make Proxmox wait on a ping that
   never comes.

   Notes:

6. [x] Write the manual bootstrap half of the runbook
   **What:** runbook section 3a — install from ISO, assign WAN and the three VLAN
   interfaces, set their addresses from the static table, enable the API and create a key.
   **Why:** PLAN.md makes this boundary explicit rather than apologetic, and this section
   is what a proof run would be executed from. It is also the only place a reader learns
   which settings are deliberately not code.
   **How:** fill in the placeholder using the split from task 1. End the section with the
   exact environment variables the next half expects, so the handover is unambiguous.
   **Accept:** no placeholder text left in runbook section 3a. Every interface address in
   it matches `docs/network-design.md`. The section ends with the exact env var names
   section 3b consumes.

   Notes: split into two explicit passes, not one list — steps 1-5 happen before
   the VLAN devices exist (VM boot, install, WAN assignment, API enablement),
   step 6 happens after task 8's terraform apply creates them (assignment +
   static addressing). Named the assigned interfaces MGMT/SERVERS/CLIENTS rather
   than leaving OPT1-3, since every later reference reads better that way. Also
   renamed section 3's remaining placeholder to "3b" so 3a/3b map directly to the
   PLAN.md decision's two halves.

7. [x] Write the opnsense/ provider configuration and variables
   **What:** `opnsense/provider.tf` and `opnsense/variables.tf` — the firewall URL and the
   API credentials read from `OPNSENSE_API_KEY` and `OPNSENSE_API_SECRET`.
   **Why:** this root has its own state and lifecycle per its skill, so it needs its own
   provider configuration rather than sharing the Proxmox root's.
   **How:** credentials from environment variables only, never a file. Keep the pinned
   `0.26.0` exactly as it is — bumping it is a separate, deliberate commit per
   `docs/conventions.md`.
   **Accept:** `terraform init -backend=false && terraform validate` is green in
   `opnsense/`. URL and credentials come from variables only, no literal in any committed
   file. `versions.tf` still pins `0.26.0`.

   Notes: confirmed the provider natively reads OPNSENSE_URI/OPNSENSE_API_KEY/
   OPNSENSE_API_SECRET (a third var beyond what the task text named), so
   `provider.tf` has an empty body, same pattern as `terraform/providers.tf`.
   `variables.tf` also declares trunk_parent_interface — task 8 needs it as the
   VLAN parent, and its value is exactly what runbook 3a step 3 has someone note
   by hand. Real fmt/init/validate all green.

8. [x] Write opnsense/interfaces.tf and opnsense/dhcp.tf
   **What:** whichever VLAN interface resources the spike found to be code-side, and a Kea
   DHCP scope serving the Clients VLAN only, pool `10.10.30.100`–`10.10.30.200`.
   **Why:** DHCP on VLAN 30 is what lets CL01 prove DHCP and domain join together, and
   VLANs 10 and 20 deliberately get no scope because every host on them is static.
   **How:** every VLAN ID and parent interface matches `docs/network-design.md` exactly.
   Hand out DC01 at `10.10.20.10` as the DNS server in the scope — a domain member that
   resolves through the firewall cannot find a domain controller. That sharpens the DNS
   paragraph in `docs/network-design.md`, which currently says only that PowerShell sets
   DNS at first boot; update the doc in the same commit so the two agree.
   **Accept:** `terraform validate` green. Every VLAN ID and parent interface matches
   `docs/network-design.md`. Exactly one Kea scope, on VLAN 30, pool
   `10.10.30.100`–`10.10.30.200`, DNS option `10.10.20.10`. VLANs 10 and 20 have no scope.
   The DNS paragraph in the design doc agrees, in the same commit.

   8.1. [x] VLAN interfaces, matching the design exactly
   8.2. [x] Kea scope on VLAN 30 with DC01 as the DNS option
   8.3. [x] Reconcile the DNS paragraph in docs/network-design.md

   Notes: opnsense_kea_dhcpv4_subnet is subnet-based, not interface-referencing
   — no cross-reference to the VLAN resources needed, just the matching CIDR.
   Real fmt/validate both green. DNS paragraph now distinguishes DC01/SRV01
   (static, PowerShell sets DNS explicitly) from CL01 (DHCP, gets DNS from the
   Kea scope's dns_servers option instead) — the old wording implied every host
   worked the same way, which stopped being true the moment DHCP existed. Left
   an open question in a comment: whether Kea also needs a manual per-interface
   enable toggle beyond what's in this file is unconfirmed until the proof run.

   Notes:

9. [x] Write opnsense/firewall.tf
   **What:** the aliases, the least-privilege rules from task 2, and outbound NAT for the
   three lab subnets.
   **Why:** this is the milestone's actual content and the part of the project that
   demonstrates network skill rather than tool skill.
   **How:** aliases for host groups and service ports so a rule reads by name instead of
   by port number. Every rule gets a `description` saying what it is for, per the skill.
   Order matters in a filter chain, so keep the file in evaluation order and say so at the
   top. Nothing here may contradict the table from task 2.
   **Accept:** `terraform validate` green. Every rule carries a non-empty `description`.
   Every rule in the task-2 table appears exactly once, and no rule appears that is not in
   that table. The file is in evaluation order and says so at the top.

   9.1. [x] Aliases for hosts and service groups
   9.2. [x] Filter rules, in evaluation order, each with a reason
   9.3. [x] Outbound NAT to the WAN uplink

   Notes: 12 filter resources — 7 inter-VLAN (DNS and Kerberos each split into a
   TCP and a UDP rule, so the 5 client-to-DC01 services in the table become 7
   rules) plus 5 outbound. One host alias (dc01), one network alias
   (lab_networks, feeds the single NAT rule), via `opnsense_firewall_nat` (the
   "Outbound" table specifically — separate resources exist for port-forward
   and 1:1 NAT, not used here). Interface keys
   for each VLAN (opt1/opt2/opt3) are variables, not literals — genuinely
   unconfirmed until runbook 3a step 6 actually assigns them. Caught and fixed a
   real bug while writing this: an early draft interpolated
   `"${var.network_vlan_clients}0.0/24"` (renders as the wrong string) instead
   of building the subnet properly — replaced with three `locals` derived from
   the VLAN ID variables, used everywhere instead of hand-typed subnet
   literals. Real fmt/validate both green after the fix.

10. [x] Fill in the code half of the runbook and confirm CI is green
    **What:** runbook section 3b — the environment variables, the apply order for the two
    Terraform roots, and how to verify each VLAN routes. Plus a check that the Terraform
    job in CI covers `opnsense/` and `terraform/` now that both hold real resources.
    **Why:** AGENTS.md makes a layer unfinished until its runbook section is written, and
    the two-stage apply from the PLAN.md decision is the kind of ordering that is obvious
    while writing it and lost a month later.
    **How:** state plainly that the verification steps have never been executed, per the
    execution status decision. Confirm the CI matrix picks up both roots and that a
    deliberately malformed resource actually turns the job red.
    **Accept:** section 3b lists the env vars and the apply order for the two roots, and
    states the steps have never been executed. The CI Terraform matrix covers both
    `terraform/` and `opnsense/`. A deliberately malformed resource turns the job red, and
    is reverted before the task is checked off.

    Notes: also added OPNSENSE_URI to the env var table — a third variable the
    provider reads natively, discovered in task 7, that the original task text
    didn't name. Confirmed real, not assumed: pushed this milestone's actual
    code as a PR (`feature/no-ref/opnsense-vlan-routing`) and watched all 6 CI
    jobs go green, `terraform (opnsense)` and `terraform (terraform)` both
    included — the matrix needed no changes since it already covered both
    roots from Milestone 2. Then, on a separate throwaway branch/PR off this
    one, added a nonexistent argument to `opnsense/dhcp.tf`, confirmed
    `terraform (opnsense)` alone went red (`terraform (terraform)` stayed
    green, correctly isolated) at the `terraform fmt` step, then deleted the
    branch without merging — same pattern as Milestone 2 task 8.

    Notes:

## Milestone 5: Terraform provisions DC01, SRV01 and CL01 from the templates

The three Windows guests become code: cloned from the two Packer templates, tagged,
VLAN-pinned, addressed by reservation, and handed to `powershell/` over WinRM. Ends when
both Terraform roots validate green with all four VMs declared. Nothing is applied —
there is still no host.

Branch this milestone per `docs/conventions.md`: one branch, one commit per task, one PR.

1. [x] Update the DHCP and addressing design in docs/network-design.md
   **What:** a reservation-only scope on the Servers VLAN with no dynamic pool, a
   reservation for CL01 on the Clients VLAN, and a paragraph saying the reservation is a
   bootstrap mechanism that PowerShell later replaces with a static address.
   **Why:** the DHCP section currently states VLANs 10 and 20 have no scope at all, which
   the bootstrap decision in PLAN.md now contradicts. The design document is the spec every
   other layer implements, so it changes first, never last.
   **Accept:** the DHCP section describes a pool-less Servers scope, names both server
   reservations at 10.10.20.10 and 10.10.20.11, makes CL01's reservation mandatory rather
   than optional, and the static address table still shows the same addresses it does now.

   Notes: gave CL01 a fixed reservation address (10.10.30.50, outside the pool)
   rather than leaving it floating — "mandatory reservation" needs an actual
   address to reserve. Static address table rows for DC01/SRV01 now describe
   the two-phase bootstrap-then-static path instead of just saying "static", so
   a reader isn't left wondering how a no-DHCP host gets its first address.

2. [x] Add a MAC address scheme to docs/conventions.md
   **What:** a fixed MAC for each of the four guests, in a locally administered range, with
   the rule that derives it from the VMID.
   **Why:** a DHCP reservation keys on MAC, so the address only stays stable across a
   rebuild if Terraform pins the MAC rather than letting Proxmox generate one. That makes
   the MAC an interface between the Terraform root and the OPNsense root, and both sides
   need one document to read it from.
   **How:** derive it from the VMID already assigned, so the MAC and the VMID cannot
   disagree. Use a locally administered prefix, never a vendor OUI.
   **Accept:** conventions lists one MAC per guest, each derivable from that guest's VMID
   by the stated rule, and no two are equal.

   Notes: `02:00:00:00:` + VMID as 4 hex digits — 101→...00:65, 201→...00:C9,
   202→...00:CA, 301→...01:2D. `02` is locally-administered unicast (bit 1 set,
   bit 0 clear), never a real OUI. OPNsense gets one too even though it has no
   DHCP reservation of its own — the task named all four guests, and a blanket
   "every guest has a documented MAC" rule is simpler than an exception.

   Notes:

3. [x] Add the reservations to opnsense/dhcp.tf
   **What:** a Servers VLAN Kea scope with reservations and no pool, plus a CL01
   reservation in the existing Clients scope.
   **Why:** this is the half of the bootstrap decision that lives in code, and without it
   tasks 4 to 7 produce VMs that boot with no address and no way in.
   **How:** addresses from `docs/network-design.md` and MACs from `docs/conventions.md` —
   neither invented here. Comment that the absent pool is deliberate, or a later reader
   will read it as an unfinished resource.
   **Accept:** `terraform validate` passes in `opnsense/`; the Servers scope declares no
   pool range; every reservation's address and MAC match the two design documents exactly.

   Notes: reservations reference their subnet by `subnet_id`
   (`opnsense_kea_dhcpv4_subnet.<x>.id`), confirmed from the real schema, not
   assumed. Real fmt/validate both green. Also fixed the same stale
   "cannot be applied" claim in the terraform-opnsense skill that
   terraform-proxmox's already had corrected.

4. [x] Write terraform/vm-dc01.tf
   **What:** DC01 cloned from `tpl-winsrv2025-de-v1`, VMID 201, VLAN 20, pinned MAC, tags
   `lab` and `role-dc`, sized per `docs/hardware.md`.
   **Why:** the domain controller is the guest everything else in the lab depends on, and
   the first one to exercise the clone-from-template path the Packer milestone built.
   **How:** `clone` block referencing the template by name from `docs/conventions.md`, not
   by VMID, so a template version bump is a one-line change. Guest agent enabled, unlike
   the OPNsense VM — these images have the tools installed.
   **Accept:** `terraform validate` passes in `terraform/`; the resource sets an explicit
   `vm_id` of 201, an explicit `vlan_id` of 20, the pinned MAC from task 2, and both tags.

   Notes: "by name" is a `proxmox_virtual_environment_vms` data source filtered
   on name+template=true, feeding `clone.vm_id` — confirmed this data source
   exists and returns `vm_id` per match before relying on it, rather than
   assuming. Declared once here since vm-srv01.tf clones the same template and
   both files share one root. No BIOS/EFI/TPM restated on the clone — a full
   clone inherits the template's firmware config, so restating it would just be
   a second place for it to drift. 2 cores, matching the ~8-core/4-guest host
   budget in docs/hardware.md (that doc splits RAM per guest but not cores).

5. [x] Write terraform/vm-srv01.tf
   **What:** SRV01, same template as DC01, VMID 202, VLAN 20, pinned MAC, tags `lab` and
   `role-member-server`.
   **Why:** the member server is what proves a domain join works on something other than
   the controller itself, and it shares every structural choice with DC01.
   **How:** mirror `vm-dc01.tf` and change only what genuinely differs. If the two files
   end up identical apart from four values, say so in a comment rather than reaching for a
   module — see the simplest-thing-that-works rule in PLAN.md.
   **Accept:** `terraform validate` passes; VMID 202, VLAN 20, correct MAC and tags; the
   diff against `vm-dc01.tf` touches only name, VMID, MAC, address and role tag.

   Notes: the diff touches one more value than the Accept line named — RAM
   (4096 vs DC01's 8192), since docs/hardware.md's per-guest split genuinely
   gives them different memory. Not a deviation to flag as wrong, just an
   honest count: name, vm_id, mac_address, tag and memory all differ; node,
   clone source, cpu, agent, disk and vlan_id don't. Reuses vm-dc01.tf's data
   source rather than redeclaring it. Real fmt/validate both green.

6. [x] Write terraform/vm-cl01.tf
   **What:** CL01 cloned from `tpl-win11-de-v1`, VMID 301, VLAN 30, pinned MAC, tags `lab`
   and `role-client`.
   **Why:** CL01 is where the whole project becomes visible — a workstation that joins the
   domain and shows a GPO actually applying.
   **How:** clones the client template, not the server one. Windows 11 needs the TPM and
   Secure Boot settings its template was built with, so confirm the clone carries them
   rather than assuming a clone inherits firmware configuration.
   **Accept:** `terraform validate` passes; the clone references the Windows 11 template;
   VMID 301, VLAN 30, correct MAC and tags; TPM and Secure Boot are present on the resource
   or explicitly confirmed in a comment as inherited from the template.

   Notes: did the research the task asked for and it paid off — the provider's
   own clone guide only confirms `agent` inherits from the template explicitly,
   says nothing specific about BIOS/EFI/TPM, and a real GitHub issue documents
   full clones NOT inheriting the full source config in some cases. Went with
   the safer of the two Accept paths: restated machine/bios/efi_disk/tpm_state
   explicitly rather than trust inheritance, on CL01 *and* retroactively on
   DC01/SRV01 (same risk, task 4/5 just hadn't surfaced it — this task's
   research applies to all three, so fixing only CL01 would have been
   inconsistent). First attempt used Packer's block/argument names
   (`efi_config`/`tpm_config`/`tpm_storage_pool`) by analogy with
   packer/windows-11.pkr.hcl — validate immediately rejected them; the real
   Terraform resource uses `efi_disk`/`tpm_state`/`datastore_id`, a different
   schema from Packer's plugin despite both being Proxmox tools. No
   `pre_enrolled_keys` equivalent exists here — Secure Boot's keys ship
   enrolled in the "4m" OVMF firmware image itself. Real fmt/validate green
   after the fix, on all three files.

   Notes:

7. [x] Wire the WinRM handoff to powershell/
   **What:** a connection block and provisioners on each Windows guest that upload
   `powershell/` and invoke its first-boot entry point, with the local admin and domain
   admin passwords passed as `sensitive` variables.
   **Why:** the `terraform-proxmox` skill makes this Terraform's last act — bring the VM up
   with the first-boot PowerShell in place, then stop. The secrets decision in PLAN.md
   already fixes that the passwords arrive this way rather than from a file in the guest.
   **How:** WinRM host is the reserved address from task 3, known before the VM boots.
   Upload the directory, then one `remote-exec` calling the entry point — no chain of
   inline AD commands, which the skill forbids. The scripts themselves land in Milestone 6;
   reference the path they will occupy and say so in a comment.
   **Accept:** `terraform validate` passes; every password variable is marked
   `sensitive = true`; no password appears as a literal anywhere in `terraform/`; the
   remote-exec invokes exactly one entry point rather than a list of AD commands.

   Notes: confirmed `terraform validate` (unlike `packer validate`) does not
   require a default, tested directly with a scratch variable before
   committing to no-default secrets — so `local_admin_password` and
   `domain_admin_password` have none, genuinely required, no placeholder
   needed. One entry point per guest (`Bootstrap-DC01/SRV01/CL01.ps1`, none of
   which exist yet), not one shared script — each guest's role is different
   enough that a shared entry point would just be an if/else dispatching on
   hostname; simpler to let Milestone 6 write three small scripts. Both
   passwords passed to every guest, DC01 included, even though a domain
   controller creating a domain and a member server joining one are different
   operations — Milestone 6 decides what each script actually does with them;
   this task only wires the mechanism. `https = false` on the connection block
   since nothing here has certificates configured — WinRM over HTTP inside a
   private lab VLAN no code outside this repo can reach.

   Notes:

8. [x] Write terraform/outputs.tf
   **What:** outputs for each guest's name, address and VMID.
   **Why:** Milestone 6 and the runbook both need to state where a guest is without
   re-deriving it from the design docs, and an output is the one place that cannot drift
   from what was actually declared.
   **How:** no secrets in outputs, not even marked sensitive — nothing here needs one.
   **Accept:** `terraform validate` passes; `terraform output` would name all four guests;
   no output references a password variable.

   Notes: all four guests, per the Accept line (OPNsense included, even though
   this milestone's own task list is scoped to the other three). One
   object-valued output per guest rather than 12 flat ones. Address values are
   literals matching docs/network-design.md, not resource attributes — none of
   these VMs have a Terraform-managed IP config to read one from.

9. [x] Fill in runbook sections 4 and 5
   **What:** the ordered steps to bring up DC01, then SRV01 and CL01 — the apply order
   against the already-bootstrapped firewall, what to check after each, and the same
   never-executed marker the other sections carry.
   **Why:** AGENTS.md makes a layer unfinished until its runbook section is written, and the
   ordering here is genuinely non-obvious: the firewall and its reservations must be live
   before a single Windows guest is worth starting.
   **How:** fill the existing placeholders. Point out that a guest booting before its
   reservation exists will come up unreachable, since that is the failure a first-time
   reader will hit.
   **Accept:** sections 4 and 5 contain concrete commands rather than placeholders, state
   the dependency on the firewall being bootstrapped first, and carry the never-executed
   note verbatim from the other sections.

   Notes: DC01 gets its own `-target` apply, separate from SRV01/CL01 — the
   real dependency isn't just "firewall before guests," it's "DC01 promoted
   before anything tries to join its domain," which section 5 states as its
   own precondition. Both sections flag that the Milestone 6 scripts they
   reference (Bootstrap-DC01/SRV01/CL01.ps1) don't exist yet either, so
   there's a double reason nothing here has run.

   Notes:

10. [x] Confirm CI stays green and still fails on a break
    **What:** both Terraform roots validating in CI with all four VMs and the new
    reservations declared, plus a throwaway check that a malformed resource still turns the
    job red.
    **Why:** this milestone roughly triples the amount of Terraform in the repo, and per the
    CI decision in PLAN.md static validation is the only evidence any of it is sound. A
    harness that has quietly stopped checking would be indistinguishable from a passing one.
    **How:** push the milestone branch, watch both matrix legs. Then break one resource on a
    scratch commit, confirm red, revert. Same method as Milestone 2 task 8.
    **Accept:** both matrix legs green on the real branch; a deliberately malformed resource
    produces a red run; the scratch commit is not merged.

    Notes: PR #4 (`feature/no-ref/provision-windows-guests`), all 6 jobs green
    on the real code, `terraform (terraform)` and `terraform (opnsense)` both
    included. Then a throwaway branch/PR off this one added a nonexistent
    argument to `vm-cl01.tf`; `terraform (terraform)` alone went red at
    `terraform validate`, `terraform (opnsense)` stayed green, branch deleted
    without merging — same isolation-and-cleanup pattern as Milestone 2 task 8
    and Milestone 4 task 10.

    Notes:

## Milestone 6: PowerShell brings up AD DS, DNS, the OU structure and the GPOs

<!-- DHCP dropped from this heading on 2026-09-12: OPNsense owns it and Milestone 4
     built it. The old wording came from the original project sketch. See the DHCP
     decision in PLAN.md. -->

The layer that turns three booted Windows VMs into a domain. Three entry points, one per
guest, driving themselves across reboots, implementing `docs/ad-design.md` exactly. Ends
when PSScriptAnalyzer is green on the whole layer — nothing can be run, so the analyzer
and a careful read are the only evidence.

<!-- Corrected 2026-09-12, before any task started. Milestone 5 shipped three named entry
     points (Bootstrap-DC01/SRV01/CL01.ps1) invoked from C:/lab-provisioning/, with both
     passwords as plain command-line strings — not one script taking a role parameter,
     which is what tasks 4 and 7 originally assumed. Task 11 was added for the recovery
     password Terraform does not yet pass. See the credential decisions in PLAN.md. -->

The interface Milestone 5 already fixed, which this milestone must match exactly:
`powershell/` is uploaded whole to `C:/lab-provisioning/`, and each guest runs
`Bootstrap-<HOSTNAME>.ps1` from there with `-LocalAdminPassword` and
`-DomainAdminPassword` as plain strings. Changing that shape means changing merged
Terraform, so treat it as fixed unless a task says otherwise.

Branch this milestone per `docs/conventions.md`: one branch, one commit per task, one PR.

1. [x] Fix the stale milestone numbers in docs/ad-design.md
   **What:** the closing section refers to "Milestone 5's PowerShell" and "Milestone 6
   must show CL01" — both written before the re-plan renumbered everything.
   **Why:** this document is the spec the whole milestone implements, and a reader
   following its cross-references currently lands on the Terraform milestone. It is also
   the cheapest possible fix to make before anyone works from it.
   **How:** PowerShell is Milestone 6 throughout; the CL01 verification belongs to the
   same milestone, not a later one. Check no other doc carries the same drift.
   **Accept:** no milestone number in `docs/ad-design.md` points at a milestone whose
   heading in `TASKS.md` describes different work; a grep for "Milestone" across `docs/`
   returns only correct references.

   Notes: the same drift existed in `docs/runbook.md` — section 1 (Proxmox host
   install) and section 6 (full rebuild) both still said "Milestone 2" / "Milestone
   7" from before the dropped-host replan; both are Milestone 8 now. Also fixed one
   more: section 3's "domain verification waits for Milestone 5" conflated DC01
   existing as a VM (Milestone 5) with the domain actually being up
   (Milestone 6). `docs/conventions.md`'s and `PLAN.md`'s own "Milestone N"
   references were checked too and are all still accurate — no change needed there.

2. [x] Write the shared PowerShell module
   **What:** `powershell/SILab.psm1` — logging to a transcript, the phase marker read and
   write, a scheduled-task register and unregister pair, and a guard that makes re-running
   a completed phase a no-op.
   **Why:** the reboot decision in PLAN.md puts all sequencing inside the guest, so every
   phase needs the same state handling. Writing it once is what makes the idempotency rule
   in AGENTS.md achievable rather than aspirational.
   **How:** Windows PowerShell 5.1 only — no ternary, no null-coalescing, and watch the
   file encoding trap the global `powershell` skill describes. Every state-changing
   function gets `[CmdletBinding(SupportsShouldProcess)]`. Log to a fixed path under
   `C:\ProgramData`, never the user profile, since phases run as SYSTEM after a reboot. The
   module is imported from `C:/lab-provisioning/`, where Terraform's file provisioner puts
   the whole `powershell/` directory — not from a system module path.
   **Accept:** PSScriptAnalyzer clean at Error and Warning; every exported function that
   changes state declares `SupportsShouldProcess`; re-running a phase whose marker is
   already set returns without acting, visible by reading the guard.

   Notes: confirmed real, not assumed — PSScriptAnalyzer 1.25.0 (the exact version
   CI pins) is installable locally after all, so every script in this milestone is
   run through it before being committed, not just left for CI to catch. Two real
   findings from that first run: `PSUseShouldProcessForStateChangingFunctions`
   flags `Start-`/`Stop-` verbs too, not just New/Set/Remove, so both transcript
   functions got `SupportsShouldProcess`; and `PSUseBOMForUnicodeEncodedFile`
   flags a `.psm1`/`.ps1` file containing non-ASCII characters with no BOM as a
   Warning (a 5.1 encoding trap the global skill's guidance is about JSON/data
   files, not source files) — resolved by keeping the file plain ASCII (no
   em-dashes in comments) rather than adding a BOM, sidestepping the trap
   entirely. Seven exported functions: `Start-`/`Stop-SILabTranscript`,
   `Get-SILabPhase`, `Test-SILabPhaseComplete`, `Set-SILabPhase`,
   `Register-`/`Unregister-SILabResumeTask`. The phase marker is a small JSON
   file (`Number`/`Name`/`Timestamp`), written via `[IO.File]::WriteAllText`
   with a UTF-8-no-BOM encoding rather than `Set-Content`, per the same 5.1
   encoding-trap guidance. `Register-SILabResumeTask` uses an `AtStartup`
   trigger under the `SYSTEM` principal, not `AtLogOn` — nobody logs on to
   these guests between phases.

3. [x] Write the first-boot phase: hostname, static address, DNS
   **What:** the phase that renames the guest, replaces its DHCP-reserved address with the
   static one from `docs/network-design.md`, points DNS at DC01, and reboots.
   **Why:** the bootstrap decision in PLAN.md is explicit that the reservation is
   scaffolding and the running state is static — a domain controller must not need DHCP to
   come back after a reboot. This is the phase that makes that true.
   **How:** parameters come from Terraform's entry point invocation, not from a file baked
   into the image. DC01 points DNS at itself once promoted; before promotion it needs a
   resolver that exists, so set that order deliberately and comment why.
   **Accept:** PSScriptAnalyzer clean; the static address written matches the address
   table for that host; no address is hardcoded in a way that contradicts
   `docs/network-design.md`; the phase marker advances and a reboot is requested.

   Notes: a real tension surfaced while writing this, not spelled out in the
   task text: DC01's phase (task 4) needs the DSRM recovery password, and
   SRV01's phase 2 (task 7) needs the domain admin password, but per the
   credential-ordering decision in PLAN.md neither password may survive a
   reboot, and Terraform invokes each entry point exactly once. If this
   addressing phase rebooted on its own (as its wording literally suggests),
   the resumed, scheduled-task-triggered invocation would have neither
   password available, since only the very first invocation carries
   Terraform's command-line arguments. Resolved by NOT calling
   Restart-Computer at the end of this phase on either host: it writes the
   phase-1 marker and falls straight through, in the same invocation, into
   the credentialed phase that follows (promotion on DC01, join on SRV01) -
   that phase's own reboot (Install-ADDSForest's, Add-Computer's) is the only
   one, and it fires after the credential is already consumed. A second
   consequence: SRV01's hostname change moves out of this phase entirely and
   into Add-Computer -NewName during its join (task 7), a single supported
   rename+join operation, rather than a separate Rename-Computer here - DC01
   has no such combined cmdlet for promotion, so its rename genuinely does
   stay in this phase, left pending (no -Restart) until Install-ADDSForest's
   reboot finalizes both together. Confirmed real, not assumed: both files
   run clean through the locally-installed PSScriptAnalyzer 1.25.0 (see task
   2's note) once `PSAvoidUsingPlainTextForPassword` was suppressed via
   `SuppressMessageAttribute` on both password parameters on both scripts
   (the same accepted tradeoff task 4 anticipates for the recovery password -
   these arrive as CLI arguments and cannot be SecureString) - and along the
   way found that the attribute only takes effect placed at the
   script/function scope naming its target parameter, not attached directly
   to the parameter declaration inside `param()`, which silently does
   nothing. `PSReviewUnusedParameter` is also suppressed for
   `LocalAdminPassword` on both scripts (never used by either - it only ever
   authenticates Terraform's own WinRM session) and for
   `DomainAdminPassword` on DC01 only (DC01 never joins anything); SRV01's
   `DomainAdminPassword` is left un-suppressed and currently still flags as
   unused, since task 7 is what consumes it.

4. [x] Write the domain controller promotion phase
   **What:** the phase that installs AD DS, creates the forest `ad.silab.internal` with
   NetBIOS `SILAB` at the 2025 functional level, renames the default site, and reboots.
   **Why:** this is the centre of the whole project — every later task, and the client
   proof in task 7, depends on this forest existing exactly as `docs/ad-design.md`
   specifies.
   **How:** `Install-ADDSForest` reboots on its own, so the phase marker must be written
   before the call, not after, or the resume lands in the wrong phase. The recovery
   password arrives as a plain string parameter (task 11 adds it to Terraform) and is
   converted to a `SecureString` on the first line that touches it — Terraform passes
   command-line arguments, so the script cannot receive a `SecureString` directly. This
   phase is the last one on DC01 that has any credential at all; everything after it runs
   as SYSTEM on a domain controller, per the credential decision in PLAN.md. Site rename is
   a separate, idempotent step.
   **Accept:** PSScriptAnalyzer clean; domain name, NetBIOS name, functional level and
   site name all match `docs/ad-design.md` exactly; the recovery password is converted to a
   `SecureString` before use and appears in no log line or transcript; the marker is written
   before the promotion call; no phase after this one on DC01 takes a credential.

   Notes: added `-SafeModeAdminPassword` to Bootstrap-DC01.ps1's own parameters
   now, ahead of task 11 actually wiring it into Terraform's invocation - the
   promotion phase needs the parameter to exist before it can be told to
   populate it. `ForestMode`/`DomainMode` use the literal string `'Win2025'`
   as this project's best-available reading of "functional level 2025" - the
   exact enum name a real Windows Server 2025 AD DS module expects is
   unconfirmed until the Milestone 8 proof run, flagged in a comment the same
   way Milestone 3 flagged the Windows 11 image-index name. Site rename
   (`Default-First-Site-Name` -> `SILAB-Lab`) and pointing DC01's own DNS at
   itself both landed as phase 3, not folded into phase 2, because they need
   the forest to already exist and so can only run on the resumed,
   post-reboot invocation - along with a `Set-DnsServerForwarder` call to
   OPNsense (10.10.20.1) that the task text didn't ask for explicitly but
   `docs/network-design.md`'s DNS section already specifies for DC01's
   resolver role. Phases 2 and 3 both run with no credential-losing reboot
   between them and phase 1 (see task 3's note) or each other - only
   Install-ADDSForest's own reboot fires, between phase 2 and phase 3.
   Confirmed real: PSScriptAnalyzer 1.25.0 flags `ConvertTo-SecureString
   -AsPlainText` as `PSAvoidUsingConvertToSecureStringWithPlainText`, an
   Error-severity rule (not just Warning) - suppressed via the same
   `SuppressMessageAttribute` mechanism as task 3's plaintext-password
   findings, since this exact conversion is what the credential decision in
   PLAN.md requires, not an oversight to fix.

5. [x] Write the OU tree and the two groups
   **What:** the `SILAB` top-level OU with `Computers/Servers`, `Computers/Workstations`,
   `Users`, `Groups` and `Service Accounts` beneath it, plus `SILAB-Admins` and
   `SILAB-Helpdesk` as global security groups.
   **Why:** `docs/ad-design.md` explains the shape as deliberate — the split under
   `Computers` is what makes the two baseline GPOs scopable at all, so task 6 cannot work
   without it.
   **How:** create parents before children and make each creation idempotent, since a
   retried phase will find some of the tree already present. Do not touch the built-in
   `Domain Controllers` OU — the design says DC01 never moves out of it.
   **Accept:** PSScriptAnalyzer clean; the created tree matches the diagram in
   `docs/ad-design.md` node for node; re-running creates nothing and errors on nothing;
   no code moves DC01's computer object.

   Notes: landed as phase 4 in Bootstrap-DC01.ps1, right after the site-rename
   phase, via two small local functions (`New-SILabOrganizationalUnit`,
   `New-SILabGroup`) rather than the shared module - task 2 scoped
   `SILab.psm1` to logging/phase/resume-task concerns only, and nothing but
   DC01 ever creates an OU or a group, so there is no second caller to
   justify putting this there instead. Both functions do their own
   existence check (`Get-ADOrganizationalUnit`/`Get-ADGroup` with a
   `-Filter` string, per the AD scripting reference) before creating
   anything, which is what makes a retried phase 4 safe even though the
   outer phase-marker guard already prevents that in the normal path. The
   domain DN comes from `(Get-ADDomain).DistinguishedName` rather than a
   hardcoded `DC=ad,DC=silab,DC=internal` literal, so it can never drift
   from `$script:ForestDomainName`. Both groups land in the `Groups` OU,
   which the task didn't say explicitly but is the only OU in the tree
   that makes sense for them.

6. [x] Write the three baseline GPOs
   **What:** the domain password and lockout policy at the root, the Workstation Baseline
   linked to `Computers/Workstations`, and the Server Baseline linked to
   `Computers/Servers`.
   **Why:** the GPOs are the visible output of the whole directory design, and the
   Workstation Baseline's logon banner is the single screenshot that proves a policy
   actually applied rather than merely being linked.
   **How:** one function per GPO, each creating the object, setting its values and linking
   it. Settings come from the table in `docs/ad-design.md` and nowhere else. Linking is
   separate from creating so a re-run can repair a missing link without rebuilding the
   policy.

   6.1. [x] Password and lockout policy at the domain root
   6.2. [x] Workstation Baseline, including the logon banner
   6.3. [x] Server Baseline

   **Accept:** PSScriptAnalyzer clean; every setting traces to a row in the GPO table in
   `docs/ad-design.md`; each GPO is linked to exactly the container that table names;
   re-running relinks nothing twice and creates no duplicate policy.

   Notes: a real split surfaced while writing this - the GroupPolicy module's
   `Set-GPRegistryValue` only reaches Administrative Template / Preference
   registry values, which cleanly covers the logon banner, wallpaper,
   Defender, firewall and the SMB1 registry toggle. Min password length,
   complexity, lockout threshold, and the audit categories are Account
   Policy / legacy Audit Policy settings instead, which live in a GPO's
   GptTmpl.inf on SYSVOL and have no dedicated cmdlet at all. Wrote a shared
   `Set-SILabSecurityTemplate` helper that creates that file directly and
   wires the Security Settings client-side extension GUID onto the GPO's AD
   object (a brand-new GPO has no extensions registered, so nothing would
   ever read the file otherwise), used by both the password-policy GPO and
   the audit half of the Server Baseline GPO. This is real, documented
   secedit/GptTmpl.inf mechanics, not invented, but three specific details -
   the exact file encoding, the versionNumber bit-packing, and whether a
   fresh GPO's extension list is really empty to just overwrite rather than
   merge into - are unverified against a real domain controller until the
   Milestone 8 proof run, flagged in a comment the same way Milestone 3
   flagged its own unconfirmed details (image-index name, driver letters).
   Considered using `Set-ADDefaultDomainPasswordPolicy` instead for the
   password policy, since it is the cmdlet that actually backs Windows'
   effective enforcement regardless of GPO - decided against it because the
   task explicitly wants a real GPO object created and linked, and
   substituting a different mechanism would leave that row undemonstrated.
   Linking uses `Get-GPInheritance` to check for an existing link before
   calling `New-GPLink`, since linking an already-linked GPO errors instead
   of no-op-ing. The Workstation Baseline's wallpaper value is a placeholder
   path to the stock Windows 11 default image - `docs/ad-design.md` names
   the setting, not a specific file, and this project has no wallpaper
   asset of its own.

7. [x] Write the domain join phase for SRV01 and CL01
   **What:** the phase that joins a member to `ad.silab.internal` and places its computer
   object in `Computers/Servers` or `Computers/Workstations` according to its role.
   **Why:** `docs/ad-design.md` requires SRV01 to land in `Computers/Servers` and CL01 in
   `Computers/Workstations`, and Terraform only creates VMs — it knows nothing about OUs.
   Placement at join time is also what puts each machine in scope of the right baseline
   GPO immediately.
   **How:** join directly into the target OU rather than joining and then moving, so the
   machine never sits briefly in the default `Computers` container out of GPO scope. The
   target OU is fixed per script — `Bootstrap-SRV01.ps1` and `Bootstrap-CL01.ps1` are
   separate files, so there is no role parameter to branch on. The join credential arrives
   as a plain string and becomes a `PSCredential` immediately. The join reboots, so it must
   be the last credential-consuming step in its script. Waiting for DC01 to answer is part
   of this phase, since a member booting first is a normal race.
   **Accept:** PSScriptAnalyzer clean; each script targets the OU `docs/ad-design.md`
   names for that host, with no role branching; the join credential appears in no log line
   or transcript; no phase after the join takes a credential; re-running on an
   already-joined machine is a no-op.

   Notes: writing this surfaced a real gap in task 4's already-committed
   code, fixed here rather than left for later - DC01 never actually did
   anything with `DomainAdminPassword`, but SRV01/CL01 need to authenticate
   their join as `Administrator` with that exact password, and a brand-new
   forest's domain Administrator account starts out with whatever password
   the local Administrator account had *at promotion time*, not a value set
   afterwards. So DC01's promotion phase (task 4) now resets its local
   Administrator's password to `DomainAdminPassword` immediately before
   calling Install-ADDSForest, which is the only point where changing it is
   both possible (the domain does not exist yet to change a domain account
   directly) and safe (still the same invocation Terraform's argument
   arrived in, so nothing has to survive a reboot). Removed the
   `PSReviewUnusedParameter` suppression for `DomainAdminPassword` on DC01
   accordingly, since it is genuinely used now. `Wait-SILabDomainController`
   (LDAP port 389 against `DC01.ad.silab.internal`, 15s poll, 900s timeout)
   is duplicated identically in both Bootstrap-SRV01.ps1 and the new
   Bootstrap-CL01.ps1 rather than added to SILab.psm1 - task 2 scoped that
   module to logging/phase/resume-task concerns only, and this is a small
   enough function that two copies read better than a third caller
   justifying a shared one. Both scripts use `Add-Computer -NewName` to join
   and rename in one supported operation (no separate Rename-Computer, no
   role parameter to branch on - each script's target OU is a fixed
   string), landing the computer object directly in its target OU. CL01
   never gained an addressing phase at all - it stays on DHCP permanently
   per `docs/network-design.md` - so its join is phase 1, not phase 2.

8. [x] Write the health check script
   **What:** `powershell/Test-SILab.ps1` — a read-only check that the forest, OU tree,
   groups, GPO links and both member joins are in the state the design documents describe,
   printing a pass or fail line per item.
   **Why:** this is the script a proof run would actually be judged by, and the only thing
   in the repo that states what "working" means in checkable terms rather than prose.
   **How:** read-only throughout — no `Set-`, no `New-`, nothing that changes state, so it
   is safe to run repeatedly on a live domain. One check per row of the design tables. Exit
   non-zero if any check fails, so it can gate a runbook step.
   **Accept:** PSScriptAnalyzer clean; the script contains no state-changing cmdlet; every
   check maps to a specific row in `docs/ad-design.md` or `docs/network-design.md`; it
   exits non-zero when any check fails.

   Notes: one `Test-SILabCheck` wrapper (takes a description and a
   scriptblock, prints `[PASS]`/`[FAIL]`, tracks a failure count) drives 15
   checks total: forest/domain name, NetBIOS name, domain and forest
   functional level, the site rename, all 7 OU tree nodes, both groups
   (name, category, scope), all 3 GPOs (existence and link target), and
   both member joins (computer object present in its role's OU). Every
   cmdlet used is a `Get-*` - confirmed by re-reading the file rather than
   just asserting it, since this is the one script whose whole purpose is
   being safe to run against a live domain. Meant to run from DC01 (or any
   domain member with RSAT), not from a specific guest's Bootstrap script -
   it takes no parameters and reads the domain fresh each time.

9. [x] Complete runbook sections 4 and 5
   **What:** the remaining half of the domain controller and member sections — running the
   entry point, what each reboot looks like, how to tell a phase resumed correctly, and the
   health check as the closing step.
   **Why:** AGENTS.md makes a layer unfinished until its runbook section is written, and the
   multi-phase reboot behaviour is exactly the thing that looks like a hang to someone
   running it for the first time.
   **How:** fill in whatever Milestone 5 task 9 left as placeholders. Say plainly that a
   guest will reboot more than once and appear unreachable in between, and where the
   transcript log lives so a stuck phase can be diagnosed.
   **Accept:** sections 4 and 5 carry concrete commands, name the log path, describe the
   reboot sequence, end with the health check, and carry the never-executed marker the
   other sections use.

   Notes: section 4 initially referenced "the environment variable table
   below" for the three guest passwords, copying section 3's pattern - but no
   such table exists near sections 4/5 (the only one in this file is 3a's
   Proxmox/OPNsense credential table), and task 11 is what actually creates
   one. Fixed to name the three `TF_VAR_*` variables directly instead of
   pointing at a table that does not exist yet. Both sections now describe
   the real reboot count from tasks 3-7 explicitly - DC01 reboots exactly
   twice (promotion, then nothing else needs one), SRV01 and CL01 exactly
   once each (the join) - and name the log path
   (`C:\ProgramData\SILab\Logs`), the phase marker
   (`C:\ProgramData\SILab\phase.json`), and each guest's scheduled task name,
   so "looks unreachable" and "actually hung" have something concrete to
   check against. Both sections end by pointing at `Test-SILab.ps1` (task 8)
   as the actual verification step, run once after section 5 rather than
   duplicated per section, since it checks the whole domain state at once.

10. [x] Get PSScriptAnalyzer green and prove it still fails
    **What:** the whole `powershell/` layer clean at Error and Warning in CI, plus a
    throwaway check that a real violation still turns the job red.
    **Why:** this milestone is the first code in the repo with no validator stronger than a
    linter, and per the CI decision in PLAN.md static analysis is the only evidence it is
    sound. A analyzer that is silently skipping files looks exactly like a passing one —
    which Milestone 2 already had to fix once.
    **How:** run the command from AGENTS.md. Then add a deliberate violation on a scratch
    commit, confirm red, revert. Same method as Milestone 2 task 8.
    **Accept:** the PowerShell job is green on the milestone branch with every script
    analysed; a deliberately introduced violation produces a red run; the scratch commit is
    not merged.

    Notes: confirmed real, not assumed — ran the exact CI command locally
    through PSScriptAnalyzer 1.25.0 first (all 5 scripts, 0 issues), then
    checked PR #6's real check-runs on the milestone branch's head commit
    (b0b4fc6): all 6 jobs green, `PSScriptAnalyzer` included. Then, same
    method as Milestones 2/4/5's task 8/10, pushed a throwaway branch
    (`test/no-ref/prove-powershell-ci-catches-breaks`, off this milestone
    branch since main doesn't have `powershell/` yet) adding one deliberate
    `Write-Host` call to `Test-SILab.ps1` — chosen over a cmdlet alias after
    that alone turned out not to trigger `PSAvoidUsingCmdletAliases` on this
    analyzer version, confirmed by testing both in isolation before trusting
    either. Opened as PR #7 (I have no `gh` CLI or token in this environment,
    same gap Milestone 2 task 1 hit — the user opened it manually so the
    `pull_request` trigger would fire). Result: `PSScriptAnalyzer` alone went
    red, all 5 other jobs stayed green, correctly isolating the failure to
    this layer. Branch deleted, local and remote, without merging.

11. [x] Add the Safe Mode recovery password to terraform/
    **What:** a third `sensitive` variable in `terraform/variables.tf`, passed to DC01's
    remote-exec invocation only.
    **Why:** `Install-ADDSForest` requires a directory restore password and Terraform
    currently passes only a local admin and a domain admin password, so task 4 has nothing
    to promote the forest with. PLAN.md decided it is a separate credential rather than a
    reuse of an existing one.
    **How:** mirror the two existing password variables — no default, `sensitive = true`,
    described in terms of what it is for. Add the argument to `vm-dc01.tf` and to nothing
    else; SRV01 and CL01 have no forest to recover. Update `terraform/example.tfvars` and
    the runbook's environment variable table in the same commit.
    **Accept:** `terraform validate` passes; the variable has no default and is
    `sensitive = true`; it appears in `vm-dc01.tf` and in no other guest file; the runbook
    table lists it alongside the other two.

    Notes: "alongside the other two" assumed a table already existed for
    `local_admin_password`/`domain_admin_password` - it didn't (checked
    `terraform/example.tfvars` and every table in `docs/runbook.md`; neither
    ever listed either, correctly, since both are credentials with no
    default and don't belong in a committed file for the same reason
    `PROXMOX_VE_API_TOKEN` never did). Added a new three-row table to
    section 4 instead of a fourth row to a table that isn't there, and left
    `example.tfvars` untouched rather than adding a precedent-setting
    password row to it. Real fmt/validate both green locally
    (terraform 1.16.1-equivalent CLI happens to be installed on this
    machine, matching Milestone 4/5's own "confirmed real, not assumed"
    notes) - `dsrm_recovery_password` has no default, is `sensitive = true`,
    and is passed as `-SafeModeAdminPassword` only in `vm-dc01.tf`'s
    remote-exec; `vm-srv01.tf`/`vm-cl01.tf` are untouched, matching task 4's
    parameter list on those two scripts.

## Milestone 7: The repo reads as a finished portfolio piece

The last milestone that needs no hardware. When it lands the project is a complete
deliverable: every claim in it is true, a reviewer can follow one machine from ISO to
domain member, and what the lab does not do is stated rather than discovered.

Branch this milestone per `docs/conventions.md`: one branch, one commit per task, one PR.

1. [x] Audit every document for stale claims and wrong cross-references
   **What:** a single pass over `README.md`, `docs/*.md` and `PLAN.md` collecting
   everything that no longer matches the repo, written up as a checklist the later tasks
   work from.
   **Why:** six milestones of decisions have moved underneath the early documents. The
   Active Directory design already needed its milestone numbers corrected once, and the
   README still describes one Packer image when there are two. A portfolio piece whose own
   documentation contradicts itself is worse than a smaller one that does not.
   **How:** grep for milestone numbers and check each against `TASKS.md`; grep for
   "image" and "template" in the singular; check every layer description against what the
   directory actually contains. Known already: the README's "each done for real rather than
   described", its single-image wording, and its claim that Terraform clones only the three
   Windows guests when it also creates the OPNsense VM.
   **Accept:** a written list of every stale claim with its file and line; every milestone
   number referenced in `docs/` matches the heading in `TASKS.md`; no item on the list is
   left without either a fix task or a note saying why it stands.

   Notes: milestone numbers are all correct — Milestone 6 task 1 already fixed
   `ad-design.md` and `runbook.md`, and every remaining reference matches its heading
   here. Nothing to do there. The audit also exposed a gap in this milestone's own
   plan: tasks 2 and 5 cover the top-level README and `docs/README.md`, but nothing
   covered the four per-layer stub READMEs. Added as task 11.

   Still outstanding, owned by tasks 2 to 6:
   - `README.md:5` "a Windows Server 2025 image" — singular; there are two templates.
   - `README.md:11` "each done for real rather than described" — flatly contradicts the
     execution status section below it. The worst claim in the repo.
   - `README.md:42` packer row "Builds the Windows Server 2025 base image" — singular.
   - `README.md:43` terraform row "Clones DC01, SRV01, CL01 from that image" — omits the
     OPNsense VM this root also creates, and "that image" is now two.
   - `README.md:44` powershell row omits `Test-SILab.ps1`, the health check.
   - `README.md:29-36` reading order omits `docs/conventions.md` — the only file in
     `docs/` that nothing links to — and has no walkthrough entry.
   - `docs/README.md` is five lines, not an index of the design documents.
   - `PLAN.md` has 31 decisions and no index; nothing links to an individual entry.

   Found and already fixed — see tasks 7, 8, 9 and 11 below.

2. [x] Rewrite the README opening and layer index
   **What:** the two opening paragraphs and the layer table, corrected to describe two
   images, four VMs, and what each directory genuinely does.
   **Why:** this is the first thing a reviewer reads, and it currently ends on "each done
   for real rather than described" — which the execution status section four screens down
   flatly contradicts. That contradiction is the single worst thing in the repo.
   **How:** say what the project is and what it demonstrates without claiming it has run.
   The execution status section is where that question gets answered, and it already
   answers it well; the opening should not pre-empt it with a claim it then withdraws.
   **Accept:** no sentence in the README's first screen asserts the lab has been run or
   built; the layer table names two Packer images and lists the OPNsense VM under
   `terraform/`; the opening and the execution status section agree.

   Notes: the opening now points forward to the execution status section instead of pre-empting it with a claim it withdraws four screens later.

3. [x] Add a limitations and next-steps section to the README
   **What:** what the lab deliberately does not do — no high availability, no clustering,
   no backup, no monitoring, no hybrid identity, one site, never applied to hardware — and
   the short list of what would come next.
   **Why:** PLAN.md's "Not in scope" list holds most of this already, but it is in a file a
   skim reader never opens. Naming the gaps on the front page before a reviewer finds them
   reads as scope control; leaving them to be discovered reads as oversight.
   **How:** pull from the "Not in scope" list rather than inventing a second one, so the two
   cannot drift. Keep next steps short and honest — a second domain controller for
   replication, and the proof run that is already Milestone 8.
   **Accept:** every item in the section traces to a line in PLAN.md's "Not in scope" or to
   a milestone in `TASKS.md`; the section names the never-applied status without repeating
   the execution status table; it is under a screen long.

   Notes: written as a table of "left out / why" rather than a list, so each gap reads as a decision. Every row traces to PLAN.md's "Not in scope" or to Milestone 8.

4. [x] Write docs/walkthrough.md
   **What:** one document tracing a single machine end to end — CL01 from blank ISO to a
   domain-joined client with the logon banner applied — naming which layer does what at
   each step and linking to the file that does it.
   **Why:** the decision in PLAN.md makes this the reader-facing surface. The design docs
   are reference and the runbook is operational; neither tells the story, and the story is
   what distinguishes this from following a tutorial.
   **How:** follow the real chain: Packer bakes the Windows 11 template, Terraform clones
   it and pins its MAC, OPNsense hands that MAC its reserved address, `Bootstrap-CL01.ps1`
   renames and joins it into `Computers/Workstations`, the Workstation Baseline GPO lands
   and the banner appears. Each step gets a sentence on why it happens there and a link.
   Write it in the same never-executed voice as the runbook.
   **Accept:** every step names a real file in the repo and links to it; the chain has no
   gap where a reader would ask "how did it get an address"; the document states it
   describes an unexecuted design; it fits on roughly two screens.

   Notes: traced against the real code rather than the design docs — that is what surfaced the details worth keeping, that CL01's reserved address sits outside the dynamic pool and that the MAC is an interface between two Terraform roots. All twelve links verified.

5. [x] Wire the walkthrough into the README and docs/README.md
   **What:** the walkthrough placed first in the README's reading order, and
   `docs/README.md` turned into a real index of the design documents rather than three
   lines.
   **Why:** a document nobody is pointed at may as well not exist, and the reading order is
   currently a list of reference material with no obvious entry point for someone who does
   not yet know what the project is.
   **How:** walkthrough first, then the design docs, then the runbook, then PLAN.md for the
   reasoning. Add `docs/conventions.md`, which the reading order omits entirely.
   **Accept:** the walkthrough is the first item in the reading order; every file in `docs/`
   appears in `docs/README.md` with a one-line description; the link checker in CI passes.

   Notes: `docs/conventions.md` had been linked from nowhere at all — it is now item 4 in the reading order and a row in the index.

6. [x] Add a navigable index to the PLAN.md decision log
   **What:** a short index at the top of the decisions section linking to each entry.
   **Why:** 31 decisions is the most valuable content in the repo and the least navigable.
   A reviewer who wants to know why the domain is not `.local` should not have to scroll
   through thirty entries to find out whether the question was even considered.
   **How:** an additive index only — do not reorder, retitle or rewrite any existing entry.
   The decision history is the point, and editing it to look tidier destroys it.
   **Accept:** every decision heading appears in the index exactly once, in file order; no
   existing decision entry's text changed in this commit's diff; every anchor resolves.

   Notes: index generated from the headings by script rather than typed, and the commit asserted everything from the first decision heading onward was byte-identical before writing. 31 rows, every anchor resolves.

7. [x] Verify the architecture diagram is current and renders on GitHub
   **What:** the Mermaid diagram in the README and the fuller one in
   `docs/network-diagram.md`, checked against the design and against GitHub's renderer.
   **Why:** the diagram is the only visual this project has — there are no screenshots,
   because nothing has run. If it does not render, the README's most valuable element is a
   block of source code.
   **How:** confirm both diagrams match `docs/network-design.md` after six milestones of
   changes. Check the line breaks in node labels actually render, rather than showing a
   literal escape, since GitHub's Mermaid version is stricter than some editors.
   **Accept:** both diagrams render on the GitHub page with no literal escape sequences
   visible; every host, VLAN and subnet shown matches `docs/network-design.md`.

   Notes: three problems, not one. The `\n` line breaks were replaced with `<br/>` in
   ten places — Mermaid documents `<br/>` and `\n` is not reliable across renderer
   versions. CL01 was missing its address entirely; it now shows the reserved
   `10.10.30.50`. And OPNsense drew an edge to the `proxmox` subgraph that contained it,
   which is nonsense — the host's management interface is now its own node. **Not fully
   verified:** rendering can only be confirmed by pushing and looking at the GitHub page.
   The escape sequences are provably gone; how it looks is not.

8. [x] Read the runbook end to end as one document
   **What:** a continuity pass over `docs/runbook.md` — that sections 2 to 5 read as one
   sequence, and that sections 1 and 6 are clearly marked as needing a host rather than
   looking unfinished.
   **Why:** the runbook was written a section at a time across four milestones, by which
   point nobody has read it straight through. It is also the document a proof run would be
   executed from, so a gap between sections is a real failure, not a cosmetic one.
   **How:** read it as someone with a host and no other context. Check that each section
   ends where the next begins, that every environment variable is introduced before use,
   and that the two deferred sections say plainly that they wait on hardware.
   **Accept:** no section references a variable, file or state that an earlier section did
   not produce; sections 1 and 6 name Milestone 8 as their owner; the never-executed marker
   is present and consistent across every section.

   Notes: found a real bug, not a cosmetic one. Section 3a step 1 said to run a plain
   `terraform apply` to create the firewall VM, which was true when it was written but
   has been wrong since Milestone 5 put all four guests in that root — following it now
   would build the three Windows machines before the network exists to serve them, and
   each would hang on a WinRM handoff to an address nothing is answering. Now
   `-target`ed at the OPNsense VM. Also moved the environment variable table to the top
   of 3a, since step 1 already needed two of its entries, and removed two bare "task 8"
   references a runbook reader has no way to resolve.

9. [x] Confirm hardware.md still reads correctly with no host chosen
   **What:** the hardware document reviewed now that buying a host is no longer the plan.
   **Why:** it was written in Milestone 1 expecting hardware to be purchased, and it still
   documents two NIC layouts with a note to narrow to one once a host is chosen. The proof
   run decision changed that to rented bare metal, which makes both layouts live options
   rather than a pending choice.
   **How:** keep both layouts, but reframe the note so it reads as a deliberate choice left
   open, not as an unfinished decision. Check nothing in it assumes ownership of a machine.
   **Accept:** no sentence in `docs/hardware.md` implies a host will be bought or that a
   decision is outstanding; both NIC layouts are presented as valid; it agrees with the
   proof run decision in PLAN.md.

   Notes: the purchase framing was easy to remove, but the document also assumed the WAN
   uplink is a DHCP lease from the home network — an assumption rented bare metal does
   not satisfy, since there is no home router and usually one NIC with a public address.
   Added a section naming both differences and the consequence: on rented metal the
   default-deny posture becomes load-bearing rather than decorative, because the firewall
   faces the public internet.

10. [x] Final read as a stranger, with CI green
    **What:** one pass through the whole repository in reading order, as someone who has
    never seen it, followed by a green CI run on the milestone branch.
    **Why:** this is the milestone's actual acceptance test. Every earlier task fixes a
    known problem; this one is the only chance to catch what nobody thought to look for.
    **How:** start at the README and follow the reading order without opening anything it
    does not link to. Note every point where a question goes unanswered. Fix what is
    cheap, and add anything expensive as a new task rather than silently leaving it.
    **Accept:** the reading order answers what the project is, what it demonstrates, and
    whether it has run, without the reader opening an unlinked file; CI is green on the
    branch; any unresolved finding exists as a written task rather than an unrecorded gap.

    Notes: 73 internal links checked, none broken; every claim from task 1's audit confirmed cleared. The read found two more, both fixed here: the README architecture diagram drew the Proxmox host as a peer of OPNsense when OPNsense is a VM on it, and the execution status section said "every claim below", which reached past the section into Scope. **CI not verified** — it cannot run on this machine and nothing was pushed from here. No code changed this milestone, so only the markdown link check is materially affected and that was approximated locally; confirm on the next push. **Process deviation:** this milestone landed as direct commits to `main`, not a branch and one PR as in Milestones 4 to 6.

11. [x] Correct the four per-layer stub READMEs
    **What:** `packer/README.md`, `terraform/README.md`, `powershell/README.md` and
    `opnsense/README.md`, each describing what its directory actually contains now.
    **Why:** added by task 1's audit, which found three stale claims in them that no other
    task covered. These files are one click from the layer index, so a reviewer who follows
    it reads them — and two still described a single Packer template and a Terraform root
    that does not create the firewall.
    **How:** two images not one; Terraform creates four VMs including OPNsense, which boots
    an ISO rather than cloning; PowerShell gains the health check and a pointer to the
    `powershell-provisioning` skill. Keep them to the few lines they already are.
    **Accept:** no stub README describes a single Packer image or omits the OPNsense VM from
    `terraform/`; `powershell/README.md` names `Test-SILab.ps1` and both skills; each file is
    still under six lines; every skill and path they name exists.

    Notes: writing these exposed a separate problem. `powershell/README.md` needed to point
    at the `powershell-provisioning` skill, and that skill was not in the repository — pull
    request #8 merged an earlier state of the Milestone 6 branch, so neither the skill nor
    the `AGENTS.md` edit pointing at it ever reached `main`. Both were stranded on
    `feature/no-ref/ad-powershell-layer-v2` and have been recovered. Worth checking whether
    anything else from that branch was left behind the same way.

## Milestone 8: The lab is applied once on rented bare metal and the evidence is captured

**Do not start this milestone until Milestones 9 and 10 have landed.** They are numbered
after it but run before it: the decision was to make the whole deployment zero-touch
before paying for a proof run, so this milestone should end up running one command rather
than the runbook by hand. The numbers stay as they are because seven files outside this
one already refer to the proof run as Milestone 8. Task 1's spike is largely answered by
Milestone 9's second spike, and tasks 4 to 7 describe the manual path; revise them when
Milestone 10 lands, not before.

Optional by design — everything above stands without it. This is the milestone that turns
"this should work" into "this ran", for roughly the price of a meal.

It is also the only milestone whose `Accept` lines describe observable behaviour rather
than a validator's opinion, because for the first time there is a machine to observe. And
the only one that spends money while it runs: the machine is billed by the hour, so the
protocol in task 2 exists to stop a debugging session becoming a bill.

Branch this milestone per `docs/conventions.md`: one branch, one commit per task, one PR.

1. [ ] SPIKE: which hourly bare metal product can actually run Proxmox (max 2h)
   **Why:** the proof run decision in PLAN.md names Scaleway and Hetzner as examples, not
   as a choice. Hourly billing, a custom OS install and roughly 32 GB of RAM are three
   constraints that eliminate most products, and finding that out with a machine already
   rented is the expensive way to learn it.
   **How:** for each candidate check four things — billing granularity actually hourly and
   not daily or monthly; whether Proxmox can be installed at all, by custom ISO, rescue
   mode or a Debian image plus the Proxmox repository; RAM and disk against
   `docs/hardware.md`; and whether the host firewall can restrict inbound traffic to one
   address, which task 4 depends on. Note the hourly rate and the minimum billing period.
   Output: one decision entry in PLAN.md naming the provider, the product and the rate

2. [ ] Write the run protocol into docs/proof-run.md
   **What:** the rules the run follows, written before it starts — the destroy deadline,
   the per-failure time box, the budget ceiling, and what counts as done.
   **Why:** every rule here is one that gets abandoned under pressure once a machine is
   running and something is broken. Writing them down beforehand is the only time they can
   be decided calmly, and a forgotten running machine is the single most likely way this
   milestone costs real money.
   **How:** fifteen minutes per failure, then capture and move on. A hard destroy deadline
   set before renting. A stated ceiling at which the run stops regardless of progress.
   State plainly that the machine gets destroyed even if the run fails, because fixing the
   code offline is free and fixing it on the clock is not.
   **Accept:** the file exists before any machine is rented; it names a destroy deadline, a
   per-failure time box and a budget ceiling as specific numbers, not adjectives.

   Notes:

3. [ ] Resolve the public-WAN deltas before renting anything
   **What:** the concrete changes needed because OPNsense's WAN faces the public internet
   instead of a home router, decided and written down while it is still free to think.
   **Why:** `docs/hardware.md` names the problem but does not solve it. Every value in
   `docs/network-design.md` that mentions `192.168.1.0/24` has to be read as "the uplink",
   and the default-deny posture stops being a demonstration and becomes the only thing
   between the lab and the internet.
   **How:** walk the firewall policy table and mark every rule whose meaning changes.
   Decide whether the WAN address is static from the provider or DHCP. Confirm nothing in
   `opnsense/firewall.tf` permits inbound WAN traffic — and if the run needs inbound access
   at all, that it is scoped to one address, never left open.
   **Accept:** a written list of every design value that changes under a public uplink; no
   rule in `opnsense/firewall.tf` accepts unsolicited inbound WAN traffic; the decision on
   static or DHCP WAN addressing is recorded.

   Notes:

4. [ ] Rent the machine, install Proxmox, and restrict access to one address
   **What:** runbook section 1 executed for real — the machine rented, Proxmox installed,
   and the host firewall restricting the web interface to your own public address before
   that interface is reachable at all.
   **Why:** this is a hypervisor on the public internet holding every VM in the lab. The
   access decision was to allow-list rather than tunnel, which works only if the rule is in
   place first and verified from somewhere else.
   **How:** install per the provider's mechanism from task 1. Set the host firewall rule
   **before** starting or exposing the Proxmox web service, not after. Then verify from a
   second network — a phone on mobile data is enough — that the port is refused. Note your
   public address in `docs/proof-run.md`; if it changes mid-run the interface locks you out,
   which is the expected behaviour, not a fault.
   **Accept:** Proxmox reachable from your address; the same port provably refused from a
   different network, checked and recorded; runbook section 1 filled in with what was
   actually done, and its "not started" marker removed.

   Notes:

5. [ ] Run runbook section 2 — both Packer templates
   **What:** `packer build` producing `tpl-winsrv2025-de-v1` and `tpl-win11-de-v1` on the
   real host.
   **Why:** the image build has never run, and it is the layer with the longest feedback
   loop and the most unknowns — the German ISO's image-index names have been flagged as a
   residual unknown since the Windows 11 spike.
   **How:** follow the section as written and change nothing on the machine that is not
   also changed in the repository. A fix applied by hand is a fix that does not exist.
   Apply the task 2 time box per failure.
   **Accept:** both templates exist in Proxmox with the VM IDs and tags
   `docs/conventions.md` specifies, or the failure is captured in `docs/proof-run.md` with
   the exact error and the step it occurred at.

   Notes:

6. [ ] Run runbook section 3 — OPNsense routing the VLANs
   **What:** the firewall VM created, installed and bootstrapped by hand, then
   `terraform apply` in `opnsense/` creating the VLANs, DHCP, rules and NAT.
   **Why:** this is the first test of the manual and code halves meeting at the boundary
   PLAN.md drew between them, and of whether the pre-1.0 provider's resources behave as
   their documentation claims.
   **How:** the `-target` on the first apply matters — the root holds all four guests and a
   plain apply would start the Windows machines before the network exists. Record which
   settings the provider could not manage and had to stay manual; that is a correction to
   the boundary decision, not a workaround.
   **Accept:** each VLAN interface answers on its gateway address; a client on the Clients
   VLAN receives a lease from the reservation; every provider resource that failed is
   recorded with the reason.

   Notes:

7. [ ] Run runbook sections 4 and 5 — the domain and both members
   **What:** DC01 promoted, SRV01 and CL01 joined, all three driven by their own Bootstrap
   scripts across their own reboots.
   **Why:** the reboot-resume mechanism and the credential ordering are the two most
   intricate decisions in the project and the two with the least static verification. This
   is the first and only time either is actually exercised.
   **How:** watch the phase markers and transcripts under `C:\ProgramData\SILab` rather
   than guessing from the machine's reachability — a guest mid-reboot looks identical to a
   hung one. Confirm each computer object lands in the OU it was joined into, not the
   default container.
   **Accept:** `Test-SILab.ps1` runs and its full output is recorded, pass or fail; every
   failing check is captured with the phase and transcript line it came from.

   Notes:

8. [ ] Capture the evidence
   **What:** the screenshots and command output that become `docs/proof-run.md` — the CL01
   logon banner above all, plus the forest, the OU tree with both computer objects, the
   firewall rules, and the complete health check output.
   **Why:** `docs/ad-design.md` named the logon banner as the one visible proof that a
   policy reached a workstation, and the whole lab has been built toward it. Capturing
   happens before the machine is destroyed, and there is no second chance.
   **How:** capture more than seems necessary — a screenshot costs nothing now and cannot
   be retaken later. Include failures, which are more interesting than successes and are
   what task 11 works from. Check every image for a credential, an API token or a public
   address before it goes anywhere near a commit.
   **Accept:** the logon banner screenshot exists; the full `Test-SILab.ps1` output is
   saved; no captured image or transcript contains a password, token or key, checked
   deliberately rather than assumed.

   Notes:

9. [ ] Destroy the machine and confirm billing stopped
   **What:** the server released, and the provider's console confirming it is gone and no
   longer accruing charges.
   **Why:** this is the task that protects the budget, and the one most likely to be
   skipped because the interesting work already happened. It runs whether the lab worked or
   not — fixing the code offline is free.
   **How:** confirm task 8's captures are safely off the machine first, then destroy.
   Check the provider's billing page afterwards rather than trusting the delete button, and
   record the actual total cost in `docs/proof-run.md`.
   **Accept:** the provider's console shows no running resource; the final cost is recorded;
   nothing needed from the machine remains only on it.

   Notes:

10. [ ] Write docs/proof-run.md and retire every "never executed" claim
    **What:** the proof run written up, and every marker in the repository that says the lab
    has not run updated to say what actually happened.
    **Why:** those markers exist in the README, all four runbook sections and several design
    documents precisely so this moment is a documentation change rather than a rewrite. The
    execution status decision in PLAN.md says the wording changes the moment a proof run
    lands.
    **How:** date, provider, cost, duration, what worked, what did not, and the evidence.
    Be as plain about the failures as about the successes — a run where everything worked
    first time would be the least believable outcome in the repository.
    **Accept:** no "never executed" marker remains that is now false; the README execution
    status section describes the run and links to `docs/proof-run.md`; the write-up states
    what failed, not only what worked.

    Notes:

11. [ ] Turn what broke into tasks, and close runbook section 6
    **What:** every failure captured during the run written up as a real task, and runbook
    section 6 completed or explicitly retired.
    **Why:** the value of the run is the list of things that were wrong, and that value
    evaporates if it stays in a write-up nobody works from. Section 6 was written to cover a
    full rebuild from zero, which is exactly what this run performed from a clean host.
    **How:** one task per failure, with the captured error, in a new milestone if there are
    enough to warrant one. For section 6, either fill it in from what this run did or mark
    it `[~]` with the reason — a second full replay costs another rental and proves the same
    thing twice.
    **Accept:** every failure in `docs/proof-run.md` appears as a task or is explicitly
    dismissed with a reason; runbook section 6 is either written or retired, with no
    placeholder left behind.

    Notes:

## Milestone 9: Every step that needed a human is code

Zero-touch, part one. Every manual step in the runbook becomes something a machine does:
the Proxmox host installs itself from an answer file, the firewall is a Packer template
that boots already routing with its API enabled, and every credential is generated rather
than typed. Nothing is orchestrated end to end yet — that is Milestone 10. And nothing is
run: there is still no host, so this milestone ends at validated, like every milestone
before the proof run.

This milestone reverses standing decisions, so task 3 records the replacements in
`PLAN.md` before any code is written against them. Per `AGENTS.md`, a rejected option
stays rejected until its entry is replaced.

Numbered after Milestone 8 but runs before it — see the note at the top of Milestone 8.

Branch this milestone per `docs/conventions.md`: one branch, one commit per task, one PR.

1. [x] SPIKE: can Packer drive the OPNsense installer and bake a config that boots routing (max 3h)
   **Why:** OPNsense has no API for assigning a device to an interface or addressing it —
   its interfaces API has eleven controllers and none does that — and neither its
   installer nor its config importer runs unattended. Typing through the installer is the
   only route to a hands-off firewall, and every later firewall task depends on whether it
   works. Guessing here builds a template on keystrokes nobody has seen land.
   **How:** check four things against the pinned `hashicorp/proxmox` plugin 1.2.3 and the
   current OPNsense installer. Does `proxmox-iso` support `boot_command` with enough wait
   control to survive the installer's prompts? Does config reach the disk better through
   the importer, typed via `boot_command`, or by copying `config.xml` over SSH after
   install? Do the NIC device names `vtnet0` and `vtnet1` stay stable when Terraform clones
   the template, since the baked assignment depends on them? Can an API key and secret be
   generated outside OPNsense and written into `config.xml`, so the key exists the moment
   a clone boots?
   Output: one decision entry in PLAN.md, stating which of the four held and which did not

   Notes: researched live (2026-09-12) against OPNsense's own documentation and issue
   tracker rather than assumed. All four held: `boot_command` is already proven twice
   against Windows installers, so it can drive `bsdinstall`'s dialogs the same way; the
   config-importer (a second FAT/FAT32 volume with `/conf/config.xml`, loaded before the
   installer runs) is real, documented, and is OPNsense's own route for scripted
   deployment, not a workaround; `vtnet0`/`vtnet1` naming is PCI-slot order, stable as
   long as Terraform's clone keeps the template's `network_device` order; API secrets are
   stored as a SHA-512-crypt hash identical in shape to `passwd`'s, so both the real
   secret and its hash can be generated offline. One residual unknown carried to task 7:
   whether the importer's device scan also reads an ISO9660 disc (what
   `additional_iso_files` produces) or needs a raw FAT32 disk image instead — OPNsense's
   own docs only describe a USB drive. Found and fixed in passing: the proof-run decision
   in PLAN.md named Hetzner as an hourly-billed example without checking; see task 2.
   Decision in PLAN.md.

2. [x] SPIKE: can the rented host install Proxmox unattended, and how does its token reach the operator (max 3h)
   **Why:** Proxmox's automated installer is real — `proxmox-auto-install-assistant`
   prepares an ISO carrying `answer.toml`, it runs headless, and it supports first-boot
   hooks. What is unproven is whether an hourly bare metal product will boot that ISO at
   all, and how a token minted by a first-boot hook gets back to whatever runs Terraform.
   This largely answers Milestone 8's first spike.
   **How:** for each candidate provider, check custom ISO boot or IPMI virtual media, and
   whether `answer.toml` can be embedded in the ISO, which needs no DHCP or DNS the
   provider controls. Decide where orchestration runs — an operator workstation, or the
   hypervisor's own first-boot hook — and how the token travels: fetched over SSH, or
   posted to the installer's post-install webhook.
   Output: one decision entry in PLAN.md naming the provider, the answer file delivery, and where orchestration runs

   Notes: `proxmox-auto-install-assistant prepare-iso` confirmed real and current
   (Proxmox VE 8.2+): embeds `answer.toml` (plaintext `root-password` in `[global]`) plus
   a first-boot script ordered `fully-up`, which is the point at which a hook can safely
   mint API tokens. The bigger finding was that the proof-run decision's own framing
   needed checking, not just Milestone 9's: Hetzner's actual dedicated-hardware line
   (Server Auction/Robot) bills monthly, not hourly — only its virtualized Cloud product
   is hourly, and Cloud instances are exactly the "unreliable nested virtualization"
   category that decision already rejects. Scaleway's Elastic Metal is genuinely hourly
   with no commitment fee, genuinely bare metal, and lists Proxmox VE as a catalog image
   directly. Corrected the proof-run decision in place rather than leaving it wrong.
   Orchestration: chose an operator workstation running `scripts/deploy.sh` (Milestone
   10) over the hypervisor's own first-boot hook driving the whole build — the hook's
   only job is minting the Terraform and Packer tokens and writing them to a root-only
   file, fetched over the same SSH connection Milestone 8 task 4's host firewall rule
   already allow-lists. Decision in PLAN.md, which also amends the proof-run decision.

3. [x] Replace the decisions this milestone reverses
   **What:** `PLAN.md` entries recording the move to zero-touch, with every superseded
   entry marked.
   **Why:** standing decisions say the opposite of what this milestone builds. "The
   OPNsense bootstrap is manual" rejected seeding a config file. "The manual/code boundary
   is interface assignment and addressing" made that boundary a person's job. And nothing
   records that zero-touch now comes before the proof run. Code written against these
   first would contradict the plan it claims to implement.
   **How:** add `Replaced by:` to the manual bootstrap decision. Amend the boundary
   decision rather than retract it: its finding still holds and is now stronger, since no
   API version can assign interfaces — only its consequence changes, from manual to baked
   into a template. Say why the old config.xml rejection no longer applies: it rejected a
   file seeded at first boot, unversioned and brittle, whereas a template's config lives in
   the repository and is rebuilt deliberately. Record both spikes' outcomes, the generated
   secrets, and the milestone order.
   **Accept:** every decision this milestone contradicts carries `Replaced by:` or an
   amendment naming what changed; each new entry has a Why and at least one Rejected; the
   decision index regenerates with every anchor resolving.

   Notes: added decision 35 as the umbrella entry — `Replaced by:` on decision 20,
   `Amended by:` on decision 24, both linking to it. Confirmed real, not assumed: wrote a
   small script checking every `](#...)` anchor in `PLAN.md` against every `###` heading's
   GitHub-style slug; all of this task's new links resolve, and the one pre-existing miss
   (decision 10's own anchor) predates this milestone and isn't this task's to fix.
   Generated secrets recorded in the new entry: the OPNsense root password/API key/secret
   and the Proxmox root password/two tokens, all extending the existing `.env` file rather
   than opening a new secrets category.

4. [x] Add the new names and layout to docs/conventions.md
   **What:** the OPNsense template's name and VMID, the new `proxmox/` directory for the
   host install, and a top-level `scripts/` directory for operator tools.
   **Why:** Terraform clones templates by name, so `tpl-opnsense-v1` is an interface
   between Packer and Terraform exactly like the two Windows templates, and it needs one
   written source. The host install and the operator scripts are new layers with no home;
   naming them first avoids a later move.
   **How:** extend the template table and give the firewall template the next VMID in the
   reserved `9000`–`9099` range. Keep `scripts/` apart from `.github/scripts/`: those are
   CI checks, these run against a real host.
   **Accept:** `tpl-opnsense-v1` and its VMID appear in the template table, clear of every
   existing template and guest VMID; `proxmox/` and `scripts/` are described with what
   belongs in each; the markdown link check passes.

   Notes: `tpl-opnsense-v1` at VMID 9002, the next free slot after the two Windows
   templates and clear of every guest VMID. Also added an ISO row for the official
   OPNsense installer media, matching the existing VirtIO/Windows ISO rows, since
   task 7 needs one and none existed. Went one step further than the task's own How and
   added `proxmox/`/`scripts/` rows to `AGENTS.md`'s own layout table too — cheap, and
   leaving a new top-level directory undocumented there is exactly the kind of gap
   Milestone 7's audit called out. Confirmed real: `check-markdown-links.py` and
   `check-design-consistency.py` both still pass.

5. [x] Write scripts/init-env.sh
   **What:** a script that writes `.env` from `example.env` with every locally generatable
   credential filled in, and refuses to touch a `.env` that already exists.
   **Why:** zero-touch means nobody types a password. Generating credentials into `.env`
   keeps the `.env` decision intact and keeps secrets out of Terraform state, which
   `random_password` resources would not.
   **How:** strong random values for the three guest passwords, written so
   `PKR_VAR_local_admin_password` and `TF_VAR_local_admin_password` are identical — Packer
   bakes that one into the templates and Terraform authenticates with it. Also the OPNsense
   root password, API key and API secret, if task 1 confirmed those can be generated
   outside OPNsense. Leave the Proxmox tokens as placeholders; task 9's hook mints them.
   Exit non-zero rather than overwrite, and create the file readable by its owner only.
   **Accept:** run twice, the second run exits non-zero and leaves the first `.env`
   byte-identical; the two local-admin variables always hold the same value; the file is
   created with owner-only permissions; `shellcheck` passes.

   Notes: also generates the OPNsense root password's and API secret's sha512crypt
   hashes with `openssl passwd -6` (task 1's SPIKE confirmed the format), since
   `config.xml` needs the hash, not the plaintext — both go into three new
   `example.env` placeholders (`PKR_VAR_opnsense_root_password`,
   `_root_password_hash`, `_api_secret_hash`), and the stale comment there claiming
   the OPNsense API credentials "don't exist until the manual bootstrap" was fixed in
   the same commit. Real bug caught by actually running the script, not just reading
   it: `set -euo pipefail` plus a bare `x="$(tr ... | head -c N)"` assignment is a
   classic trap — `tr` reading `/dev/urandom` never reaches EOF, so it always dies of
   SIGPIPE the moment `head -c` stops reading, and with `pipefail` on, that non-zero
   status silently aborted the script right after the very first secret was
   generated, before any substitution ran, with no error printed. Fixed by scoping
   `set +o pipefail` to the two generator functions, which is safe since each runs in
   its own command-substitution subshell. Confirmed real end to end in a scratch
   copy: `shellcheck` clean; first run substitutes every generatable field and
   leaves the two Proxmox tokens as `REPLACE_ME`; the two local-admin values match;
   both hashes are well-formed `$6$...`; a second run exits 1 and leaves `.env`
   byte-identical; permissions are `600`.

6. [x] Template the OPNsense config.xml
   **What:** a committed `config.xml` template under `packer/files/` holding the interface
   assignments, addresses, VLAN devices and API user the firewall boots with, with every
   secret as a placeholder filled from `.env` at build time.
   **Why:** this file replaces the manual bootstrap, so everything runbook section 3a does
   by hand has to be in it. The repository is public, so it must never carry a real
   credential, or a hash of one, into git.
   **How:** WAN on the WAN NIC; VLANs 10, 20 and 30 on the trunk NIC, assigned and
   addressed from `docs/network-design.md`; the API enabled for the user task 5 generated a
   key for. Placeholders for the root password hash and the API key. Only what the API
   cannot do goes in here — firewall rules, DHCP and NAT keep their Terraform resources in
   `opnsense/`.
   **Accept:** every address, VLAN ID and interface in the template matches
   `docs/network-design.md`; no password, hash or key value is present, only placeholders;
   gitleaks finds nothing in it.

   Notes: pulled `opnsense/core`'s real `config.xml.sample` from GitHub rather than
   guessing the schema, and confirmed live that OPNsense's VLAN device IDs are
   sequential `vlanN` since the 22.1.4 overhaul, not `<parent>_vlan<tag>` — flagged
   the exact vlan0/vlan1/vlan2 assignment as a residual unknown for the proof run
   since nothing else references it directly. Used Packer's native `templatefile()`
   `${...}` syntax instead of a moustache-style placeholder needing an external
   render step — `cd_content` in task 7 can pass this file straight through
   `templatefile()`, no separate render-and-gitignore step needed the way task 9's
   `answer.toml` needs one. Created a dedicated `terraform` API user rather than
   attaching the API key to `root`, mirroring the existing per-tool-credential
   pattern (separate Proxmox tokens for Packer and Terraform) rather than one
   credential doing double duty. `nat`/`filter` are present but empty — Terraform
   owns their content in `opnsense/`, and an empty `<filter>` also means no
   default-allow rule is ever active, matching the least-privilege decision in
   PLAN.md more closely than OPNsense's own sample default. Extended decision 17's
   German-throughout spirit to this third template too (`de_DE`, `Europe/Berlin`,
   German NTP pool) — noted here rather than as a new PLAN.md entry, since it's an
   application of an existing decision, not a new one. Confirmed real: the file
   parses as well-formed XML, and `check-design-consistency.py`/
   `check-markdown-links.py` both still pass.

7. [x] Write packer/opnsense.pkr.hcl
   **What:** a `proxmox-iso` build that drives the OPNsense installer with `boot_command`
   and produces `tpl-opnsense-v1` with task 6's config applied.
   **Why:** the firewall becomes a template like the two Windows images, so Terraform
   clones all four guests the same way and no VM in the lab boots an installer.
   **How:** the keystroke sequence and the config route come from task 1's decision, not
   from guesswork. Substitute task 6's placeholders from `PKR_VAR_*` at build time so a
   rendered file never lands in the repository. Pin any new plugin exactly. Add the source
   to the existing build so `packer validate .` covers it with no workflow change.
   **Accept:** `packer fmt -check` and `packer validate .` pass with the new source; every
   `boot_command` step traces to an installer prompt task 1 recorded; nothing under
   `packer/` holds a rendered config with real values.

   Notes: "the existing build" read literally is impossible — the Windows build's
   provisioners (WinRM/PowerShell) have no meaning against an SSH/FreeBSD guest — so
   this is a second, separate `build` block in the new file instead, still covered
   by `packer validate .` with zero workflow changes since that command already
   walks every `.pkr.hcl` in the directory. No separate render-and-gitignore step
   needed the way task 9's `answer.toml` needs one: `templatefile()` renders
   `config.xml` straight into `cd_content` at validate/build time, so nothing
   rendered ever touches disk in this repo at all.

   A real design correction surfaced while writing this, not while researching
   task 1: OPNsense's install docs, read in full this time, say the live
   environment's login prompt itself demands the *imported* root password before
   `bsdinstall` even starts — there is no password-free path to it, which the
   SPIKE's "no rotation needed" conclusion had missed. Reverted to the Windows
   pattern for the right reason this time: `config.xml`'s root password is a fixed
   bootstrap hash (of the same non-secret `Pa$$w0rd-PackerBuild!` string, defined
   once as an HCL local and shared between the template and the new
   `rotate-opnsense-root-password.sh`, not duplicated as a literal in both), and a
   `shell` provisioner rotates it to the real secret after install. Second
   correction recorded in PLAN.md rather than a third rewrite of the same
   paragraph. `PKR_VAR_opnsense_root_password_hash` — added to `example.env` and
   `scripts/init-env.sh` in tasks 4/5 on the first (incomplete) understanding —
   turned out to be unnecessary and was removed from both in this commit; only the
   API secret's hash is still generated, since that one really is never typed
   anywhere.

   The rotation script also has to persist the change into `config.xml` itself, not
   just the live OS user table — OPNsense re-applies `config.xml`'s stored hash to
   the OS on every boot, so a `pw`-only change would silently revert on Terraform's
   first clone-and-boot. Used BSD `sed -i ''` deliberately, not the GNU form — a
   real, easy-to-get-wrong difference on a FreeBSD-based guest.

   Confirmed real, not assumed: `packer fmt`, `packer init` and `packer validate .`
   all genuinely run locally and all pass, including a first failure that was
   fixed rather than routed around — `templatefile()` tried to interpret this
   file's own prose explanation of `${...}` syntax as real interpolation, fixed
   by escaping it to `$${...}`, then confirmed by manually rendering the template
   with fake substitute values and parsing the result as XML. `shellcheck` is
   clean on the new `.sh` file. `check-design-consistency.py` and
   `check-markdown-links.py` both still pass, and `terraform validate` in both
   roots is unaffected.

   The `boot_command` sequence itself is the single least-verified artifact in
   this milestone, flagged as such in the file — the documented sequence of
   screens is real (task 1's SPIKE, confirmed again in full while writing this),
   but the exact keystroke count per `bsdinstall` dialog and the config carrier's
   device name (guessed as `cd1`) cannot be confirmed without a live install.
   Left exactly that honest rather than invented false precision.

8. [x] Clone the firewall from its template and hand the VLANs to it
   **What:** `terraform/vm-opnsense.tf` cloning `tpl-opnsense-v1` instead of booting an
   ISO, and the VLAN devices removed from `opnsense/interfaces.tf`.
   **Why:** a template that boots with its VLANs already assigned means those devices exist
   before Terraform ever connects. Leaving them in `opnsense/interfaces.tf` too would give
   one resource two owners, with Terraform trying to create what the template already made.
   **How:** mirror the Windows guests — a template lookup with a postcondition naming the
   template, and no CD-ROM. Keep the trunk NIC's documented `vlan_id` exception. Update the
   `terraform-opnsense` and `terraform-proxmox` skills wherever they describe the firewall
   booting an ISO or Terraform owning VLAN devices.
   **Accept:** `vm-opnsense.tf` has no `cdrom` block and clones by template name with a
   postcondition; `opnsense/` declares no VLAN device the template creates; both roots pass
   `terraform validate`; neither skill still describes the old arrangement.

   Notes: deleted `opnsense/interfaces.tf` outright rather than leaving it empty —
   nothing else in `opnsense/` references its resources (checked with a grep before
   removing), and an empty file with just a comment isn't a pattern used anywhere
   else in the repo. That made `trunk_parent_interface` dead too (its only
   reference was the deleted file), so it came out of `opnsense/variables.tf` and
   `example.tfvars` along with it — the trunk's device name now only matters
   inside `packer/opnsense.pkr.hcl`/`config.xml`, which don't read a Terraform
   variable for it. Also removed `terraform/`'s now-unused `iso_datastore`
   variable (only the deleted `cdrom` block read it) from `variables.tf` and
   `example.tfvars`, and fixed `opnsense/variables.tf`'s `opnsense_interface_*`
   comments, which had called opt1/opt2/opt3 an unconfirmed guess pending a
   manual runbook step that no longer exists — they're a fact the template sets
   now, not a placeholder. Gave OPNsense's WAN NIC its documented MAC
   (`docs/conventions.md`, VMID 101) for the first time — the ISO-boot version
   never set one since nothing depended on it, but the "every guest has one
   documented MAC" convention already intended it (Milestone 5 task 2's own
   note said as much). Confirmed real: `terraform fmt`/`init`/`validate` green
   in both roots, `check-design-consistency.py` and `check-markdown-links.py`
   both still pass.

9. [x] Make the Proxmox host install itself
   **What:** a templated `proxmox/answer.toml`, the step that prepares an installer ISO
   from it, and a first-boot hook that creates the API tokens Terraform and Packer need.
   **Why:** runbook section 1 is the one layer with no automation at all, and on
   hourly-billed hardware it is the most tedious. The hook closes the last chicken-and-egg
   problem: nothing can reach Proxmox until a token exists, and today a person creates it.
   **How:** answer file values from `docs/network-design.md`, including the management
   address `10.10.10.2`, with the root password a placeholder filled from `.env`. Prepare
   the ISO with `proxmox-auto-install-assistant prepare-iso` and gitignore the result,
   since it embeds the rendered answers. The hook creates separate tokens for Terraform and
   Packer so either can be revoked alone, delivered by the route task 2 chose.
   **Accept:** the answer file's addresses match `docs/network-design.md` and it holds no
   real secret; a prepared ISO or rendered answer file cannot be committed, confirmed with
   `git check-ignore`; the hook creates two distinct tokens.

   9.1. [x] `proxmox/answer.toml` template and the ISO preparation step
   9.2. [x] First-boot hook creating both tokens
   9.3. [x] Gitignore the prepared ISO and any rendered answer file

   Notes: pulled the real `answer.toml` schema from the official Proxmox wiki
   rather than trusting the two community examples found first, both of which
   used the older `root_password` (underscore) spelling — the current schema is
   kebab-case (`root-password-hashed`), confirmed by fetching the wiki page in
   full. `[network]` is static (`from-answer`, `10.10.10.2/24`) per
   `docs/network-design.md`, with DNS pointing at a placeholder public
   resolver rather than DC01 — DC01 doesn't exist yet at Proxmox-install time,
   and whether the host even sits on this address directly depends on
   Milestone 8 task 3's still-open public-WAN question; flagged in the file
   rather than guessed at. `disk-list = ["sda"]` is a placeholder too, for the
   same "no specific rented product chosen yet" reason.

   No `templatefile()` here — this render happens outside Packer entirely
   (`scripts/prepare-proxmox-iso.sh`), so plain `sed` on the one placeholder
   does the job without a new dependency, consistent with `init-env.sh`'s own
   style. A real gap surfaced while writing the render script: unlike
   OPNsense's API secret, nothing programmatic ever needs the Proxmox root
   password's *plaintext* — only its hash goes into `answer.toml` — but an
   operator still has to log in with it afterward. `init-env.sh` (from task 5)
   now also writes `PROXMOX_ROOT_PASSWORD` alongside the hash, for that reason
   alone; nothing reads it back programmatically.

   The first-boot hook mints both tokens via `pvesh create
   /access/users/root@pam/token/<id> --privsep 0` (root-equivalent, matching
   how `example.env`'s tokens were already both `root@pam`-scoped, not a new
   inconsistency) and writes lines shaped exactly like `.env`'s own variable
   names to `/root/proxmox-api-tokens.txt`, so the operator can paste them in
   directly. `--output-format json` piped through `grep -oP` avoids a `jq`
   dependency this minimal a host script shouldn't need. Confirmed the
   ordering choice against the real Proxmox wiki: `fully-up` (the default) is
   exactly the point `pvesh` is documented as available, not a guess.

   Confirmed real, not assumed, everywhere it could be: `shellcheck` is clean
   on both new scripts; the render step was actually run end to end against a
   stubbed `proxmox-auto-install-assistant` (this machine can't install the
   real one — no host, same limitation as `packer build`/`terraform apply`)
   and the rendered file parsed as valid TOML via Python's `tomllib`, with the
   right values in the right sections; `git check-ignore` confirms the
   rendered answer file and any `proxmox/*.iso` are ignored while
   `proxmox/answer.toml` itself and the two scripts are not;
   `check-design-consistency.py` and `check-markdown-links.py` both still
   pass.

10. [x] Extend CI to cover everything this milestone added
    **What:** `shellcheck` on `scripts/`, the design consistency check widened to the new
    config and answer file templates, and proof that each still fails on a break.
    **Why:** this milestone adds shell and two new files carrying lab addresses, and the
    consistency check currently scans only `.tf` and `.pkr.hcl` under `terraform/` and
    `opnsense/`. A wrong address in the firewall template would pass today.
    **How:** a `shellcheck` job. Add `packer/files/` and `proxmox/` to the consistency
    script's scanned paths, with `.xml` and `.toml`. Break each on a scratch commit the way
    Milestone 2 task 8 did.
    **Accept:** a shell error in `scripts/` turns CI red; a wrong address in the OPNsense
    template or `answer.toml` fails the consistency check naming the file and line; every
    check is green on the real branch.

    Notes: `shellcheck` needs no action or install step — it ships preinstalled on
    `ubuntu-latest`, matching the project's existing preference for a runner tool
    over a marketplace action when one already does the job. Widened the job past
    the task's own literal scope to include `proxmox/first-boot-hook.sh` alongside
    `scripts/*.sh` — it's real shell code with nothing else checking it, and the
    task's Why already worries about "this milestone adds shell" in general, not
    only the one directory. Widened the consistency script's `CODE_DIRS` to add
    `packer` and `proxmox` wholesale rather than special-casing `packer/files/` —
    the existing suffix filter already limits what actually gets read in each
    directory, so this was simpler than a per-directory suffix map for the same
    result; `packer/`'s `.pkr.hcl` suffix was already declared but never reachable
    before this, since `packer` was never in `CODE_DIRS` at all.

    Confirmed real, not assumed, for both: introduced a genuine `SC2086` violation
    (an unquoted variable) into a scratch copy of `init-env.sh` and confirmed
    `shellcheck` catches it, then reverted; changed one gateway address in
    `packer/files/config.xml` to `10.10.99.1` and confirmed
    `check-design-consistency.py` names the exact file and line, then reverted.
    **Not verified: real CI.** Same limitation as every earlier milestone's task 8
    — no `gh` CLI or token in this environment, so nothing was pushed from here.
    Every command above is the literal command the workflow runs, executed
    directly rather than approximated; confirm on the next real push.

    Notes:

11. [x] Rewrite runbook sections 1 and 3a for what now happens without a person
    **What:** section 1 describing the unattended host install, and section 3a describing a
    firewall that boots already configured, both keeping the never-executed marker.
    **Why:** `AGENTS.md` makes a layer unfinished until its runbook section is written, and
    both sections currently tell a person to type what this milestone automated. Left
    alone they would describe a procedure that no longer exists.
    **How:** describe what the automation does and what to check if it stops, not what to
    type. Keep a manual fallback only for a step a spike proved cannot be automated.
    **Accept:** neither section tells a person to type into an installer or web interface
    unless a spike recorded why; both carry the never-executed marker; the markdown link
    check passes.

    Notes: the real scope ended up wider than "sections 1 and 3a" read literally —
    3a's entire *content* (a person installing and configuring OPNsense by hand)
    is what got automated, not just its wording, so 3b's steps that interleaved
    with "3a step 6" had to be rewritten too, and section 4's opening still
    pointed at "the `.env` loaded back in section 3a," which no longer loads
    anything there. Kept the `3a`/`3b` heading split and anchors rather than
    collapsing section 3 into one flow — `opnsense/provider.tf` and
    `opnsense/README.md` both still say "runbook 3a" in a few words, and
    repointing two live cross-references was simpler than retitling the anchor
    everything else in the repo already resolves against. Fixed both of those
    files' stale "installed and API-enabled by hand" wording in the same commit,
    since they were only a few words each and now flatly wrong. Also fixed
    section 2, one section this task wasn't named for but which the same
    rewrite made stale on contact: it still said "both sources" and "one shared
    build block" when there are three sources across two blocks now, and never
    mentioned uploading the OPNsense ISO at all.

    Confirmed real: `check-markdown-links.py` and `check-design-consistency.py`
    both still pass; read the whole file start to finish afterward, the same way
    Milestone 7 task 10 did, rather than trusting the diff alone.

    Notes:

## Milestone 10: One command goes from bare metal to a verified domain

Zero-touch, part two. The operator rents a server by hand and boots the prepared installer;
from there, one command on the operator's machine takes the host to a domain that has
verified itself. Renting and releasing the server stay manual by decision, so the command
starts once the host answers SSH and ends by reminding the operator to release it.

The build runs on the Proxmox host, not the operator's machine. Neither Packer nor
Terraform can send WinRM through a jump host, so whatever runs them needs a direct route to
every build VM and guest, and only the host has one. Nothing is run here either — there is
still no host — so this milestone ends at validated.

Planning this milestone surfaced gaps in work already checked off, each written as a task
below rather than patched in passing: the Windows builds wait on a guest agent they only
install after connecting, their build VMs sit on the public bridge, the OPNsense build names
no address to connect to, the host's answer file points at a gateway that does not exist at
install time, and the Terraform handoff cannot survive its guest dropping its own address.

Numbered after Milestone 8 but runs before it — see the note at the top of Milestone 8.

Branch this milestone per `docs/conventions.md`: one branch, one commit per task, one PR.

1. [x] SPIKE: give the host a network that reaches every build VM and guest (max 3h)
   **Why:** the build now runs on the host, so the host needs a route to everything it
   connects to, in the order it connects. During `packer build` no firewall exists yet, so
   the build VMs need a network the host reaches directly — today the Windows ones sit on
   `vmbr0`, which on rented metal is the provider's public uplink, with WinRM open under a
   bootstrap password. Afterwards the host reaches the guests through OPNsense. And
   `proxmox/answer.toml` gives the host `10.10.10.1` as its only gateway, a VM that does not
   exist while the host installs. This pulls Milestone 8 task 3's public uplink question
   forward, as far as this milestone needs it answered.
   **How:** decide the host's install-time network from the provider's uplink rather than
   the lab address. Decide how `vmbr1` and the host's `10.10.10.2` on VLAN 10 get created:
   the first-boot hook, or the runner's first stage over SSH — the second also works if
   Proxmox came from the provider's own catalog image instead of the prepared ISO. Decide
   where build VMs attach and how they get an address: a build network with DHCP served by
   the host, or VLAN 10 directly. Check whether OPNsense's empty filter blocks SSH and its
   API on the VLAN 10 interface, during the build and after. Check how the host trusts its
   own `pve-root-ca`, since the Packer sources set `insecure_skip_tls_verify = false`.
   Output: one decision entry in PLAN.md, and the list of changes task 6 makes to `docs/network-design.md`

   Notes: researched live (2026-09-13) against current Proxmox/Scaleway/OPNsense
   sources, not assumed from the older plan. `answer.toml` moves to
   `source = "from-dhcp"` for the provider's uplink — confirmed against the real
   answer-file schema and Scaleway's own Elastic Metal docs. `vmbr1` (VLAN-aware,
   `bridge-vids`) and the host's own `10.10.10.2` (a `vmbr1.10` sub-interface) are
   created by the host-side runner's first stage over SSH, not
   `proxmox/first-boot-hook.sh` — keeps the hook a single-purpose appliance script
   and works the same whether Proxmox came from the prepared ISO or Scaleway's own
   Proxmox catalog image. Build VMs get a third, disposable bridge (`vmbr2`,
   `10.10.99.0/24`) with a `dnsmasq` the runner starts, rather than VLAN 10 itself
   — `docs/network-design.md` states Management has no DHCP scope at all, and reusing
   it for build traffic would either contradict that or carve an exception into it.
   Real bug found and recorded, not invented for this task: OPNsense's empty
   `<filter>` blocks `10.10.10.2` from reaching OPNsense's own API on `opt1`, since
   the automatic anti-lockout rule only ever attaches to an interface flagged `<lan>`
   and none of `opt1`/`opt2`/`opt3` carry that role — confirmed against OPNsense's
   own anti-lockout documentation and issue opnsense/core#7372, not assumed; task 6
   adds the missing rule. Residual unknown, left for the Milestone 8 proof run:
   whether Proxmox's self-signed cert's SAN actually covers the node's configured
   name closely enough for `insecure_skip_tls_verify = false` to validate once
   `pve-root-ca.pem` is trusted — not confirmable from documentation alone. Decision
   in PLAN.md.

2. [x] SPIKE: how a Linux orchestrator starts each Bootstrap script, knows it finished, and verifies the domain (max 2h)
   **Why:** the Terraform handoff runs each Bootstrap script synchronously over WinRM.
   DC01's first phase removes and re-adds its only address and its promotion reboots it, so
   the session dies mid-command; a provisioner error taints the VM, and the next apply would
   destroy and recreate a half-built domain controller. Then something has to know when every
   phase on every guest has finished, and run `Test-SILab.ps1`, from a Linux host with no
   PowerShell.
   **How:** confirm how `remote-exec` over WinRM behaves when the connection drops
   mid-command. Compare ways to launch the script detached, so the provisioner returns at
   once, without breaking the rule that no credential is written to the guest's disk — a
   scheduled task stores its arguments. Choose the completion signal, most likely each
   guest's `C:\ProgramData\SILab\phase.json`. Compare the WinRM clients available on Linux
   for polling and for running the health check: Terraform's own, reused through a
   `terraform_data` resource, against `pywinrm`.
   Output: one decision entry in PLAN.md

   Notes: the real answer was already sitting in code from Milestone 6, not a new
   mechanism — `powershell/SILab.psm1`'s `Set-SILabPhase` already writes
   `C:\ProgramData\SILab\phase.json` before every reboot-triggering call (built for
   the resume mechanism), and `Register-SILabResumeTask` already resumes with no
   credential in its argument list, confirmed by reading both files directly rather
   than assumed. So the fix is: launch each Bootstrap script via `Start-Process
   -WindowStyle Hidden` (returns at once, no disk-persisted argument, unlike a
   scheduled task) and let Terraform's `remote-exec` return immediately; the
   host-side runner then polls `phase.json` over WinRM with `curl --ntlm` in a bash
   loop, and runs `Test-SILab.ps1` the same way once every guest reaches its
   terminal phase. Chose `curl --ntlm` over both named candidates —
   `terraform_data` reusing Terraform's WinRM client (real, but turns polling into a
   `terraform apply` per attempt) and `pywinrm` (adds a pip/Python dependency whose
   maintenance status couldn't be confirmed live, disqualifying given this repo's
   pin-and-verify discipline). Confirmed live: Terraform's WinRM/SSH provisioners
   have no built-in way to survive a connection dropped mid-command by a reboot —
   a known, long-standing class of issue, not a config flag away from fixed.
   Decision in PLAN.md.

   Both choices above were corrected later, in place, once actually implemented —
   `Start-Process` in task 7, `curl --ntlm` in task 8. Neither this task's text nor
   this note is rewritten (`AGENTS.md`); see PLAN.md's decision 37 for both
   corrections and what replaced each.

3. [x] Record this milestone's decisions in PLAN.md
   **What:** entries for where the build runs, how the server is rented and released, where
   the ISOs come from, and both spikes' outcomes, with the orchestration decision amended.
   **Why:** "The Proxmox host installs itself from an answer file; its tokens travel to the
   operator over SSH" put `scripts/deploy.sh` on the operator's workstation and sent the
   tokens there. Both halves are now wrong: WinRM cannot hop through a jump host in Packer
   or Terraform, so the build moves onto the host, and the tokens never need to leave it.
   `AGENTS.md` keeps a decision standing until its entry is replaced.
   **How:** add `Amended by:` to that decision, keeping its installer finding and
   superseding its orchestration and token-delivery half. Record that renting and releasing
   the server stay manual, so no provider API key enters `.env`, and that ISOs download on
   the host from URLs in a non-secret var file. Rejected alternatives come from the planning
   questions: WireGuard from the host, SSH port forwards, the provider's API, and uploading
   ISOs from the workstation.
   **Accept:** the orchestration decision carries `Amended by:` naming what changed and
   what still stands; every new entry has a Why and at least one Rejected; the decision
   index regenerates with every anchor resolving.

   Notes: decision 34 now carries `Amended by:` pointing at the new decision 38, which
   keeps its installer finding untouched and supersedes only the orchestration-location
   and token-delivery half. Decisions 36-38 added (tasks 1, 2 and this one), each with
   a Why and at least one Rejected, `Amended by:`/`See also` links resolving both ways.
   Confirmed real, not assumed: `check-markdown-links.py` passes, which is what keeps
   the generated decision index and every cross-reference honest.

4. [x] Make every Packer build reachable from the host
   **What:** both Windows answer files install the QEMU guest agent before WinRM comes up,
   all three sources attach their build VM where task 1 decided, and the OPNsense source
   names the address Packer connects to.
   **Why:** three separate problems stop Packer reaching a build VM as written. Both Windows
   sources set `qemu_agent = true`, which is how the builder learns a build VM's address,
   but the agent is installed by `install-guest-tools.ps1`, a provisioner that runs over
   WinRM after Packer has connected — so both builds wait out their six-hour timeout. Both
   Windows build VMs sit on `vmbr0` under a comment calling it the trunk, when Terraform and
   the OPNsense build treat `vmbr0` as the WAN. And the OPNsense source disables the agent
   and sets no `ssh_host`, so Packer has no way to learn that build VM's address at all.
   **How:** add a `FirstLogonCommands` step installing `virtio-win-guest-tools.exe` from the
   VirtIO ISO already attached, ordered before the WinRM steps, and keep
   `install-guest-tools.ps1` idempotent so a re-run is harmless. Correct the bridges and the
   misleading comment. Set the OPNsense source's `ssh_host` to the address task 1 confirms
   the host can reach, and confirm against the pinned `hashicorp/proxmox` 1.2.3 that this is
   how a build without an agent is addressed.
   **Accept:** in both answer files the guest tools install is ordered before the first
   WinRM command; no Windows source attaches a build VM to the public uplink; no comment
   calls `vmbr0` the trunk; the OPNsense source sets `ssh_host`; `packer fmt -check` and
   `packer validate .` pass.

   Notes: `ssh_host` is a Packer-core SSH-communicator field, not proxmox-plugin-
   specific — applies unconditionally, no version check needed against 1.2.3. New
   `proxmox_bridge_build` variable (default `vmbr2`) replaces the hardcoded `vmbr0` on
   all four build NICs across the three sources — simpler than adding `proxmox_bridge_
   wan`/`_trunk` to Packer too, since build-time bridge assignment no longer needs to
   match production at all (the guest OS only sees vtnet0/vtnet1 PCI-slot order, never
   which Proxmox bridge sits behind it). OPNsense's build VM has no guest agent, so its
   first NIC gets a fixed MAC (`02:00:00:00:99:10`) paired with a static
   `10.10.99.10` reservation the host-runner's dnsmasq will serve (task 8) —
   `ssh_host` points at that address. Real gap surfaced by the design-consistency
   check, not anticipated: both new literals had to be added to
   `docs/network-design.md` (a new "Build network" section) and
   `docs/conventions.md` (as an explicit non-guest exception to the MAC table) in this
   same commit before the checker went green — task 6 still owns the fuller
   host-uplink/firewall-rule treatment of that section. Confirmed real: `packer fmt
   -check`, `packer init` and `packer validate .` all pass; both answer files still
   parse as well-formed XML; `check-design-consistency.py` and
   `check-markdown-links.py` both pass.

5. [x] Download every installation ISO on the host from a URL
   **What:** both Windows images, VirtIO and OPNsense fetched by the host into its datastore
   from URLs and checksums held in a non-secret var file.
   **Why:** nothing large should cross the operator's connection while the server bills.
   Datacenter bandwidth is faster, and a checksum per URL means a changed download fails
   loudly instead of quietly building a template from the wrong image.
   **How:** prefer Packer downloading on the Proxmox node itself, with `iso_url` and
   `iso_download_pve`, if the pinned `hashicorp/proxmox` 1.2.3 supports it for both
   `boot_iso` and `additional_iso_files`; otherwise `pvesh create
   /nodes/<node>/storage/<storage>/download-url` in the runner. Handle OPNsense shipping as
   `.iso.bz2` explicitly. URLs and checksums go in `packer/example.pkrvars.hcl` as
   placeholders, never in `.env`.
   **Accept:** no step uploads an ISO from the operator's machine; every download is
   checksummed; the OPNsense image's compression is handled explicitly; `packer validate .`
   passes.

   Notes: confirmed live, not assumed — fetched the pinned `hashicorp/proxmox` 1.2.3
   builder source directly (`builder/proxmox/iso/config.go`): `boot_iso` is typed as
   `common.ISOsConfig`, the exact same struct `additional_iso_files` uses, so it
   already carries `iso_url`/`iso_download_pve` — no version bump needed, and no
   `pvesh download-url` fallback either. Replaced `win_server_iso_file`/`win11_iso_file`/
   `virtio_iso_file` with `_iso_url` variables (Proxmox derives the datastore filename
   from the URL itself, so the URL's basename has to match `docs/conventions.md`'s
   table — said explicitly in a comment everywhere it matters) and wired
   `iso_download_pve = true` into both Windows sources' `boot_iso` and both `virtio`
   `additional_iso_files` blocks. OPNsense's `boot_iso` deliberately keeps its old
   `iso_file` shape — `iso_download_pve` cannot decompress `.iso.bz2`, so a new
   `opnsense_iso_url` variable exists only for the host-side runner (task 8) to
   download and decompress into `opnsense_iso_file` itself, checksumming by hand;
   nothing in `packer/*.pkr.hcl` reads it. `docs/runbook.md` section 2's "upload the
   ISOs" step is now stale but deliberately left for task 12's full rewrite rather
   than patched twice. Confirmed real: `packer fmt -check` and `packer validate .`
   both pass (only the expected "checksum is none" warnings, same as every ISO
   variable before this task); `check-design-consistency.py` and
   `check-markdown-links.py` both still pass.

6. [x] Write the provisioning paths into the network design and the firewall
   **What:** `docs/network-design.md` and `opnsense/firewall.tf` carrying the host's
   install-time uplink, the build network, and least-privilege rules for the host's own
   provisioning traffic, with `proxmox/answer.toml`'s network section corrected to match.
   **Why:** with the build on the host, `10.10.10.2` has to reach WinRM on DC01, SRV01 and
   CL01 and the OPNsense API. The firewall policy table allows none of that, so default
   deny would block the handoff. The answer file's only gateway is also a VM that does not
   exist when the host installs. Per `AGENTS.md`, the design document changes first, in the
   same commit.
   **How:** apply task 1's list. Add one row per rule — source `10.10.10.2` only, a single
   destination, a single port, and the reason — rather than opening Management to the lab.
   Replace `answer.toml`'s lab address and missing gateway with the provider uplink task 1
   chose.
   **Accept:** every new rule names `10.10.10.2` as its only source and one service port; no
   rule opens a whole VLAN; `answer.toml` names no gateway that is a lab VM; the design
   consistency check passes.

   Notes: `answer.toml`'s `[network]` now reads `source = "from-dhcp"` alone — that
   source value forbids every other network key, so `cidr`/`gateway`/`dns` are gone,
   not just changed. Four new rules on `opnsense_interface_management`
   (sequence 107-110, right after the client-to-DC01 block): the host to
   OPNsense's own API (443, for `opnsense/`'s own Terraform provider — a real,
   previously-unnoticed gap the host-network SPIKE found, since nothing had ever
   exercised that root against a real firewall) and to each of DC01/SRV01/CL01 on
   WinRM (5985). New `srv01`/`cl01`/`proxmox_host` aliases alongside the existing
   `dc01` one — SRV01 and CL01 are now destinations for the first time, so the
   Milestone 4 note explaining why they weren't is corrected in the same commit,
   not left standing next to code that contradicts it. Confirmed real: `terraform
   fmt`/`validate` green in `opnsense/`; `answer.toml` still parses as valid TOML
   (checked with Python's `tomllib`); `check-design-consistency.py` and
   `check-markdown-links.py` both pass — the new IPs needed no new doc literals
   since `10.10.10.1`/`10.10.10.2`/`10.10.20.11`/`10.10.30.50` were already in
   `docs/network-design.md`'s static address table.

   Notes:

7. [x] Make the Bootstrap handoff survive its guest dropping off the network
   **What:** the three `remote-exec` provisioners launch each Bootstrap script so the
   provisioner returns at once, per task 2, and each script writes the completion signal
   task 2 chose after its final phase.
   **Why:** as written, DC01's handoff fails the moment its first phase touches its address,
   and a failed provisioner taints the VM so the next apply destroys it. The guest already
   drives itself across reboots by design; Terraform only needs to start it and get out of
   the way.
   **How:** keep one entry point per guest and credentials passed as arguments, as the
   credential decision requires. Check where the chosen launch mechanism keeps its arguments
   and reject any that writes them to disk. Update the `powershell-provisioning` skill with
   the launch and the signal.
   **Accept:** no provisioner waits on a script that reboots or re-addresses its guest; no
   launch mechanism stores a credential on the guest's disk; the completion signal is written
   only after the final phase; `terraform validate` and PSScriptAnalyzer pass.

   Notes: task 2's own SPIKE chose `Start-Process` — writing this task's actual code
   found that mechanism doesn't work and corrected decision 37 in place, not silently.
   A real, open `PowerShell/PowerShell#16001` issue confirms a WinRM shell's job object
   kills anything started directly inside it (`Start-Process` included) the instant the
   shell closes — which Terraform's `remote-exec` does right after the launch command
   "succeeds," i.e. at exactly the moment a fast, clean return looks like it worked. The
   actual fix, confirmed against two independent real sources rather than assumed
   (Packer's own elevated-command provisioner, and Ansible's own Windows docs): a
   one-shot scheduled task, which Task Scheduler spawns outside any caller's job object
   entirely. New `Start-SILabDetached` in `powershell/SILab.psm1` registers it, starts
   it, polls `(Get-ScheduledTask).State -eq 'Running'` to confirm the real process
   exists before deleting the definition again — a real, narrow exception to "no
   credential ever written to the guest's disk" (a task definition is a file; deleting
   it removes future runs, not the instance already handed to Task Scheduler), not a
   loophole argued around it. All three `vm-*.tf` files now call it through one
   `-Command` invocation per guest, quoting every value the same single-quote-doubling
   way `terraform/locals.tf` already established, so nothing here weakens that existing
   escaping discipline. The completion signal needed no new code at all —
   `Set-SILabPhase` (Milestone 6) already writes `phase.json` before every
   reboot-triggering call; DC01's terminal phase is 5, SRV01's is 2, CL01's is 1 (read
   directly from each script, not assumed), values task 8's runner consumes directly.
   `powershell-provisioning` skill updated with both the launch mechanism and a Gotchas
   entry recording the job-object trap, so the next person touching this layer doesn't
   rediscover it the hard way. Confirmed real, not assumed: round-tripped the
   single-quote-escaping helper through actual PowerShell argument parsing (a value
   containing `'` survived intact); `terraform fmt`/`validate` green in `terraform/`;
   `Invoke-ScriptAnalyzer -Severity Error,Warning` clean on all of `powershell/`, pinned
   version 1.25.0; `SILab.psm1` parses with zero syntax errors. Residual unknown, left
   for the Milestone 8 proof run: whether `Unregister-ScheduledTask` genuinely never
   stops an already-running instance is inferred from Task Scheduler's documented
   behavior and general precedent, not confirmed against a live Windows box — flagged
   in the module's own comment, not glossed over.

   Notes:

8. [x] Write the host-side runner
   **What:** a script that runs on the Proxmox host and takes it from freshly installed to
   three built templates and four applied VMs, in order, skipping any stage whose result
   already exists.
   **Why:** this is the part of the one command that needs a direct route into the lab, so
   it runs where the route is. Re-running must be safe: a failure an hour in cannot mean
   renting a clean host.
   **How:** install the exact Terraform and Packer versions `AGENTS.md` pins into a scratch
   directory with their checksums verified, not from a package repository. Trust
   `pve-root-ca` and point `PROXMOX_VE_ENDPOINT` and `PKR_VAR_proxmox_url` at the node's own
   name, so `insecure_skip_tls_verify = false` stays honest. Merge the first-boot hook's
   token lines into the host's `.env` and delete the token file. Then build any template
   that does not exist yet, apply the firewall, apply DC01 and wait for its completion
   signal, then SRV01 and CL01, and wait again.
   **Accept:** the stages run in runbook order, sections 2 to 5; every stage checks for its
   result before acting; tool versions and checksums are pinned exactly; no step disables
   TLS verification; `shellcheck` passes.

   Notes: `scripts/host-runner.sh`, stages in order: trust `pve-root-ca` and add a
   `/etc/hosts` entry for `pve.silab.internal` (`example.env`'s endpoint placeholders
   now point there directly, a fixed value from `proxmox/answer.toml`'s own `fqdn` —
   nothing host-specific to substitute at runtime); install Terraform/Packer via
   HashiCorp's own documented SHA256SUMS+GPG-signature flow
   (`developer.hashicorp.com/well-architected-framework/verify-hashicorp-binary`), not
   a hardcoded checksum, since a value I couldn't independently verify felt worse than
   verifying against the vendor's own signed manifest at run time; create
   `vmbr1`/`vmbr2` and start `dnsmasq` on the build network (task 1's SPIKE); merge
   `/root/proxmox-api-tokens.txt` into `.env`; download and decompress OPNsense's
   `.iso.bz2` by hand (task 5); build only the templates that don't already exist,
   via `packer build -only=...` after checking each VMID with `qm status`; apply the
   firewall; apply DC01 and wait, then SRV01+CL01 and wait.

   A real gap surfaced while writing the wait step, not while researching the
   SPIKE: `curl --ntlm` (PLAN.md decision 37's original choice) cannot poll
   `phase.json` at all — WinRM is a SOAP protocol with its own
   CreateShell/Command/Receive sequence, and `curl --ntlm` only carries the
   transport underneath that. New `terraform/wait-for-guests.tf` adds one
   `terraform_data` resource per guest instead, reusing Terraform's own WinRM
   client via `terraform apply -target=... -replace=...` in a bash loop — see
   PLAN.md's second correction to decision 37. Confirmed real, not assumed:
   tested `-replace` against a scratch `terraform_data` resource locally, both
   on a resource that doesn't exist yet (creates it, no error) and one that
   does (destroys and recreates it) — exactly the retry semantics the loop
   needs. `stage_build_templates`'s per-VMID `-only` selection tested against
   mocked `qm`/`packer` commands, confirming it builds only the missing
   template. Also fixed while writing this: a `RETURN` trap intended to clean
   up each download's temp directory turned out to re-fire on every
   *enclosing* function's return too, not just its own — real, working bash
   behavior, just not the scoped cleanup it looked like; replaced with a
   plain `rm -rf` at each function's natural end and error exit instead.
   `shellcheck` and `bash -n` both clean. Residual unknown, unavoidable
   without a live host: the actual `qm`/`pvesh`/`ifreload`/`dnsmasq` commands,
   the HashiCorp release URLs, and the WinRM poll loop are all unexecuted —
   consistent with every other layer in this repo.

   Notes:

9. [x] Write scripts/deploy.sh
   **What:** the one command, run on the operator's machine with the rented server's
   address as its only argument, that copies the repository and `.env` to the host over SSH,
   runs the host-side runner, streams its output and exits with its result.
   **Why:** the operator should need SSH and nothing else — no Terraform, no Packer, and no
   route into the lab.
   **How:** fail fast if `.env` is missing, pointing at `scripts/init-env.sh`. Copy `.env`
   with owner-only permissions. Exclude `.git`, `.terraform/` and anything gitignored except
   `.env`. Keep SSH host key checking on: accept the key once, deliberately, rather than
   disabling verification for a machine on the public internet.
   **Accept:** the script takes exactly one address argument; nothing it copies is readable
   by anyone but root on the host; host key verification is never disabled; its exit code is
   the runner's; `shellcheck` passes.

   Notes: a real gap in this task's own text, found while writing it rather than
   invented scope: "exclude anything gitignored except .env" would leave
   `packer/packer.auto.pkrvars.hcl` behind — the file the operator creates locally
   with the real ISO URLs/checksums/node name, gitignored because it isn't secret,
   not because it's meant to stay off the host. Without it, `packer build` on the
   host would run entirely against `packer/variables.pkr.hcl`'s placeholder
   defaults. Copies it (and any other `*.auto.tfvars`/`*.auto.pkrvars.hcl`) alongside
   `.env` instead of literally just `.env`, and says why in a comment rather than
   silently widening scope. Uses `tar` piped over `ssh`, not `rsync` or `scp -r` —
   the operator needs "SSH and nothing else" per this task's own Why, and `tar` is
   as universal as `ssh` itself where `rsync` is not guaranteed to be installed.
   `git ls-files -z`/`find -print0` and `tar --null -T` throughout, so a filename
   with a space or newline can't break the manifest. SSH host key checking is
   simply never touched — no `StrictHostKeyChecking`/`UserKnownHostsFile` flag at
   all, which is what "accept the key once, deliberately" means in practice: the
   normal interactive prompt on first connection, not a bypass. Confirmed real,
   not assumed: ran the manifest-build-and-tar-pipe end to end locally (a scratch
   `.env` copied from `example.env`, then removed again afterward) — every tracked
   file plus `.env` arrived byte-identical on the "remote" side, and neither `.git`
   nor `.terraform` was among them. `shellcheck` needed one file-wide
   `disable=SC2029` (every `${remote_dir}`-style variable in a command string sent
   to `ssh` is deliberately expanded locally before it ever reaches the wire, not a
   collision with a same-named remote variable) with a comment saying why, matching
   this repo's existing practice of a targeted, justified disable over silencing a
   real class of mistake. Not executed against a real host — no host exists yet,
   same limitation as every other layer.

10. [x] End with the verdict, then scrub the host
    **What:** the run finishes by executing `Test-SILab.ps1` on DC01 through the client task
    2 chose, returns its result as the command's exit code, and removes every secret from
    the host once the run has passed.
    **Why:** a deployment that reports success without verifying the domain is only a
    script that stopped. And releasing the server by hand does not guarantee the provider
    wipes its disks, while the host holds `.env`, Terraform state with every credential in
    it, and the rendered answer file.
    **How:** run the health check only after every completion signal is present, and pass
    its exit code through unchanged. After a pass, scrub automatically. After a failure,
    keep the state so a re-run can continue, and print the exact command to scrub before
    releasing the server. The scrub removes `.env`, all Terraform state, the token file and
    any rendered answer file, and ends by reminding the operator to release the server in
    the provider console.
    **Accept:** the exit code is the health check's; a passing run scrubs automatically; a
    failing run keeps its state and prints the scrub command; the scrub also runs on its
    own; `shellcheck` passes.

    Notes: a fourth `terraform_data` resource, `run_health_check`
    (`terraform/wait-for-guests.tf`), `depends_on` all three `wait_*` resources and runs
    `Test-SILab.ps1` on DC01 — already there via `vm-dc01.tf`'s own `file` provisioner,
    nothing new to copy. `-File`'s own semantics make the script's `exit N` become
    `powershell.exe`'s process exit code directly, so the resource's pass/fail already
    is the health check's, with no extra wrapping needed. "The exit code is the health
    check's" reads here as pass/fail (0 or nonzero), not a promise to relay
    `Test-SILab.ps1`'s exact numeric code through Terraform's own apply exit codes,
    which Terraform does not expose a way to do. New `scripts/scrub-host.sh` removes
    `.env`, both roots' `.tfstate*`/`.terraform/` (never `.terraform.lock.hcl` — a
    committed pin, not a secret), the token file, and any rendered answer file/ISO;
    `host-runner.sh`'s `main` calls it directly on a pass and instead prints its path
    on a fail, leaving every secret in place for a re-run. `deploy.sh` mirrors this on
    the operator's side, printing the full remote scrub command with the real host
    address once the runner exits nonzero — the one thing only `deploy.sh` knows that
    the runner itself doesn't.

    A real bug caught by testing, not assumed correct: my first cut of `deploy.sh`
    read `$?` *after* the closing `fi` of `if ssh ...; then exit 0; fi` to decide what
    to print and exit with — POSIX resets the exit status of an `if` whose condition
    was false and has no `else` to 0, not the condition's own code, so this version
    would have always reported success even after a real failure. Confirmed both the
    bug and the fix by literally running both versions against a function that
    `return 7`s; the fixed version (`ssh ... || status=$?`, checked as a plain
    variable afterward) correctly captured and exited `7`. Also confirmed `rm -f`/
    `rm -rf` against a glob that matches nothing genuinely exits 0 under `set -e`
    (no `nullglob` needed) before relying on that in `scrub-host.sh`. `terraform fmt`/
    `validate` green in `terraform/`; `shellcheck` and `bash -n` clean on both
    scripts. Not executed against a real host — no host exists yet.

    Notes:

11. [ ] Extend CI to the orchestration scripts
    **What:** the new scripts under `shellcheck`, the design consistency check reading shell
    files, and proof that both still fail on a break.
    **Why:** the runner and `deploy.sh` will carry lab addresses — `10.10.10.2` and the
    guests' WinRM targets — and the consistency check reads `.tf`, `.pkr.hcl`, `.xml` and
    `.toml` but not shell. An address typed wrong in the runner would pass today.
    **How:** confirm the new scripts fall inside the existing `shellcheck` job's paths. Add
    `.sh` to the consistency script's suffixes and `scripts` to its scanned directories.
    Break each on a scratch commit, the way Milestone 2 task 8 did.
    **Accept:** a shell error in either new script turns CI red; a wrong lab address in a
    script fails the consistency check naming the file and line; every check is green on the
    real branch.

    Notes:

12. [ ] Rewrite the runbook and README around the one command, and revise Milestone 8
    **What:** runbook sections 1 to 5 describing what `deploy.sh` does and what to check when
    a stage stops, the README's execution status and next steps naming the one command, and
    Milestone 8's tasks revised for a proof run that is a single command.
    **Why:** the note at the top of Milestone 8 defers revising its manual-path tasks until
    this milestone lands, and task 1 here now answers most of its task 3. Left alone, the
    proof run would be planned around a runbook this milestone replaced.
    **How:** keep every never-executed marker. Revise Milestone 8 by marking superseded tasks
    `[~]` with a one-line reason and adding replacements at the end, never rewriting a task's
    text, per the rules at the top of this file.
    **Accept:** no runbook section tells a person to run a stage `deploy.sh` runs; the README
    names `scripts/deploy.sh` and states it has not been run; every superseded Milestone 8
    task is `[~]` with a reason, and none has had its text rewritten.

    Notes:
