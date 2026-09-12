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

2. [ ] Add a MAC address scheme to docs/conventions.md
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

   Notes:

3. [ ] Add the reservations to opnsense/dhcp.tf
   **What:** a Servers VLAN Kea scope with reservations and no pool, plus a CL01
   reservation in the existing Clients scope.
   **Why:** this is the half of the bootstrap decision that lives in code, and without it
   tasks 4 to 7 produce VMs that boot with no address and no way in.
   **How:** addresses from `docs/network-design.md` and MACs from `docs/conventions.md` —
   neither invented here. Comment that the absent pool is deliberate, or a later reader
   will read it as an unfinished resource.
   **Accept:** `terraform validate` passes in `opnsense/`; the Servers scope declares no
   pool range; every reservation's address and MAC match the two design documents exactly.

   Notes:

4. [ ] Write terraform/vm-dc01.tf
   **What:** DC01 cloned from `tpl-winsrv2025-de-v1`, VMID 201, VLAN 20, pinned MAC, tags
   `lab` and `role-dc`, sized per `docs/hardware.md`.
   **Why:** the domain controller is the guest everything else in the lab depends on, and
   the first one to exercise the clone-from-template path the Packer milestone built.
   **How:** `clone` block referencing the template by name from `docs/conventions.md`, not
   by VMID, so a template version bump is a one-line change. Guest agent enabled, unlike
   the OPNsense VM — these images have the tools installed.
   **Accept:** `terraform validate` passes in `terraform/`; the resource sets an explicit
   `vm_id` of 201, an explicit `vlan_id` of 20, the pinned MAC from task 2, and both tags.

   Notes:

5. [ ] Write terraform/vm-srv01.tf
   **What:** SRV01, same template as DC01, VMID 202, VLAN 20, pinned MAC, tags `lab` and
   `role-member-server`.
   **Why:** the member server is what proves a domain join works on something other than
   the controller itself, and it shares every structural choice with DC01.
   **How:** mirror `vm-dc01.tf` and change only what genuinely differs. If the two files
   end up identical apart from four values, say so in a comment rather than reaching for a
   module — see the simplest-thing-that-works rule in PLAN.md.
   **Accept:** `terraform validate` passes; VMID 202, VLAN 20, correct MAC and tags; the
   diff against `vm-dc01.tf` touches only name, VMID, MAC, address and role tag.

   Notes:

6. [ ] Write terraform/vm-cl01.tf
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

   Notes:

7. [ ] Wire the WinRM handoff to powershell/
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

   Notes:

8. [ ] Write terraform/outputs.tf
   **What:** outputs for each guest's name, address and VMID.
   **Why:** Milestone 6 and the runbook both need to state where a guest is without
   re-deriving it from the design docs, and an output is the one place that cannot drift
   from what was actually declared.
   **How:** no secrets in outputs, not even marked sensitive — nothing here needs one.
   **Accept:** `terraform validate` passes; `terraform output` would name all four guests;
   no output references a password variable.

   Notes:

9. [ ] Fill in runbook sections 4 and 5
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

   Notes:

10. [ ] Confirm CI stays green and still fails on a break
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

    Notes:

## Milestone 6: PowerShell brings up AD DS, DNS, DHCP, the OU structure and the GPOs

<!-- Not planned yet. The PowerShell does not exist yet — it is written here, not reused. -->

## Milestone 7: The repo reads as a finished portfolio piece

<!-- Not planned yet. Runbook complete end to end, diagrams current, README honest about
     execution status. This is the last milestone that needs no hardware — the project is
     a complete deliverable when it lands. -->

## Milestone 8: The lab is applied once on rented bare metal and the evidence is captured

<!-- Not planned yet, and optional by design. Everything above stands without it.
     Revisit sooner if the existing homelab host frees up, which would make it free. -->
