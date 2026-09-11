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

3. [ ] Write the shared Packer variables and a committed example var file
   **What:** `packer/variables.pkr.hcl` declaring Proxmox connection and node, the
   datastores, ISO paths and checksums, and the local administrator password as
   `sensitive`; plus a committed `packer/example.pkrvars.hcl` with placeholder values.
   **Why:** the secrets decision in PLAN.md routes real values through `PKR_VAR_*` and
   keeps `*.pkrvars.hcl` out of git, which leaves a reader no way to know what to set. A
   committed example file is how that gap gets closed without shipping a credential.
   **How:** one `variable` block per input with a description and type. Mark the password
   `sensitive = true`. Confirm `.gitignore` already excludes `*.pkrvars.hcl` and that the
   example filename does not match the ignore pattern, or it will silently never commit.

   Notes:

4. [ ] Write the Windows Server 2025 answer file
   **What:** `packer/files/autounattend-server.xml` — German locale throughout, UEFI/GPT
   partitioning, Desktop Experience image selection, the local administrator, and WinRM
   enabled on first boot.
   **Why:** this is the file that makes the install unattended, and per the skill it is
   allowed to do only four things. Everything else is a provisioner, so keeping it narrow
   is what stops the image from accumulating machine-specific state.
   **How:** `Microsoft-Windows-International-Core-WinPE` set to de-DE for UI, input,
   system and user locale in the `windowsPE` pass. GPT layout with an EFI system
   partition, MSR and Windows partition. Select the Desktop Experience index by its exact
   image name from the German ISO, not by number. VirtIO storage driver path added so
   Setup can see the disk. WinRM enabled from a `FirstLogonCommands` entry.

   4.1. [ ] Locale, keyboard and timezone, all de-DE
   4.2. [ ] UEFI/GPT disk layout and Desktop Experience image selection
   4.3. [ ] Local administrator and WinRM enablement

   Notes:

5. [ ] Write the Windows 11 answer file
   **What:** `packer/files/autounattend-client.xml` — the same shape as the server answer
   file, plus whatever the spike in task 1 determined is needed for a local account and
   the hardware checks.
   **Why:** CL01 is the machine that demonstrates domain join and a GPO actually applying,
   so this is the answer file the visible proof depends on.
   **How:** start from the server answer file, change the image selection to Windows 11
   Pro, and apply the spike's findings. Do not copy registry bypasses found in forum posts
   without understanding them — the VM gets a real TPM and Secure Boot in task 7, which is
   the supported path.

   Notes:

6. [ ] Write the Windows Server 2025 source and build block
   **What:** `packer/windows-server-2025.pkr.hcl` — a `proxmox-iso` source producing a
   Proxmox VM template, with the installation ISO and the VirtIO driver ISO both attached.
   **Why:** this is the artifact DC01 and SRV01 clone from, and per the skill the build is
   finished the moment Packer can reach WinRM.
   **How:** `q35` machine type with OVMF firmware and an EFI disk, `virtio-scsi-single`
   controller, a VirtIO network adapter, and the answer file delivered as an additional
   ISO. WinRM communicator with a generous timeout, since a German ISO installing updates
   is slow. Tags and template name from `docs/conventions.md`.

   Notes:

7. [ ] Write the Windows 11 source and build block with TPM and Secure Boot
   **What:** `packer/windows-11.pkr.hcl` — the client source, adding a TPM 2.0 device and
   Secure Boot to the firmware configuration.
   **Why:** Windows 11 Setup refuses to install without both, and giving the VM real
   virtual hardware is the supported way past that rather than disabling the checks.
   **How:** same shape as task 6, plus the plugin's TPM configuration block pointing at a
   storage pool for TPM state, and Secure Boot enabled on the EFI disk. Confirm the pinned
   plugin version actually supports the TPM block before relying on it — if it does not,
   that is a version bump commit of its own, not a workaround.

   Notes:

8. [ ] Write the shared provisioners
   **What:** the provisioner chain both builds run — QEMU guest agent install, Windows
   Updates, and a final cleanup pass.
   **Why:** PLAN.md specifies a patched base image, and the guest agent is what lets
   Proxmox and Terraform see a VM's address and shut it down cleanly. Without it Milestone
   5 has no reliable way to tell when a clone has finished booting.
   **How:** a Windows Update provisioner needs a second Packer plugin, so pin it exactly in
   `plugins.pkr.hcl` alongside the Proxmox one and record why it is there. Every
   provisioner must be re-runnable per the skill. No sysprep in the cleanup step — that is
   a standing decision in PLAN.md, so say so in a comment where someone would expect one.

   8.1. [ ] QEMU guest agent
   8.2. [ ] Windows Updates, with the extra plugin pinned
   8.3. [ ] Cleanup, explicitly without sysprep

   Notes:

9. [ ] Turn on packer validate in CI and get it green
   **What:** remove the Milestone 2 gate in `.github/workflows/validate.yml` that skips
   `packer validate` when no build template exists, so both builds are validated on every
   push.
   **Why:** that gate was written to be honest while `packer/` held only a plugin pin. Once
   real build blocks exist it stops protecting anything and starts hiding regressions in
   the one layer with no other feedback available.
   **How:** delete the conditional and its notice, leaving a plain `packer validate .`.
   Confirm the job actually goes red for a malformed block before trusting it, the same way
   Milestone 2 task 8 proved the rest of the harness.

   Notes:

10. [ ] Fill in the image build section of docs/runbook.md
    **What:** the ordered steps to produce both templates on a real host — upload the ISOs,
    set the `PKR_VAR_*` values, run each build, confirm the templates appear.
    **Why:** CLAUDE.md makes a layer unfinished until its runbook section is written, and
    this section is what a proof run would actually be executed from. Writing it now, while
    the build blocks are fresh, is the difference between a runbook and a reconstruction.
    **How:** fill the existing placeholder section. Mark clearly that these steps have never
    been executed, consistent with the execution status decision in PLAN.md.

    Notes:

## Milestone 4: OPNsense routes the lab VLANs

<!-- Not planned yet. -->

## Milestone 5: Terraform provisions DC01, SRV01 and CL01 from the templates

<!-- Not planned yet. -->

## Milestone 6: PowerShell brings up AD DS, DNS, DHCP, the OU structure and the GPOs

<!-- Not planned yet. The PowerShell does not exist yet — it is written here, not reused. -->

## Milestone 7: The repo reads as a finished portfolio piece

<!-- Not planned yet. Runbook complete end to end, diagrams current, README honest about
     execution status. This is the last milestone that needs no hardware — the project is
     a complete deliverable when it lands. -->

## Milestone 8: The lab is applied once on rented bare metal and the evidence is captured

<!-- Not planned yet, and optional by design. Everything above stands without it.
     Revisit sooner if the existing homelab host frees up, which would make it free. -->
