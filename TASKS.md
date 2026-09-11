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

1. [ ] Create the public GitHub repository and push
   **What:** a public repo with the Milestone 1 work in it, a description, topics, and
   `main` tracking the remote.
   **Why:** PLAN.md makes the public repo the deliverable — the link on a job
   application. Nothing in this milestone can be tested until Actions has somewhere to
   run, and task 1.2 left the repo description open pending exactly this.
   **How:** `gh repo create` as public, push `main`, set the description and topics
   (proxmox, terraform, packer, active-directory, windows-server, iac).

   Notes:

2. [ ] Add pinned provider and plugin skeletons so validation has real input
   **What:** `terraform/versions.tf`, `opnsense/versions.tf` and `packer/plugins.pkr.hcl`,
   each declaring its provider or plugin at an exact pinned version and nothing else.
   **Why:** a validation job with no files to check is green for the wrong reason. These
   three files also settle the version pinning the OPNsense decision in PLAN.md
   explicitly requires, before any resource is written against a version that might move.
   **How:** `required_providers` for bpg/proxmox and browningluke/opnsense, and
   `required_plugins` for the Proxmox Packer plugin. Exact `=` constraints, never `~>`.
   Record each chosen version and the date in the file as a comment.

   Notes:

3. [ ] CI job: Terraform formatting and validation for both roots
   **What:** a GitHub Actions job running `terraform fmt -check -recursive` and
   `terraform init -backend=false && terraform validate` in `terraform/` and `opnsense/`.
   **Why:** these two roots will hold most of the project's code, and `validate` is the
   only thing that will ever catch a bad resource argument, since nothing can be applied.
   **How:** `.github/workflows/validate.yml`, matrix over the two directories,
   `hashicorp/setup-terraform`. Backend disabled so init needs no Proxmox credentials.

   Notes:

4. [ ] CI job: Packer formatting and validation
   **What:** `packer fmt -check` and `packer init` plus `packer validate` over `packer/`.
   **Why:** the image build is the layer with the longest feedback loop even when
   hardware exists, so catching a malformed template statically is worth the most here.
   **How:** same workflow, `hashicorp/setup-packer`. `packer validate` needs a build
   block, which does not exist until Milestone 3 — gate the validate step on one being
   present so the job is honest rather than skipped silently.

   Notes:

5. [ ] CI job: PSScriptAnalyzer over powershell/
   **What:** a job running PSScriptAnalyzer across `powershell/`, failing on Error and
   Warning severities.
   **Why:** the PowerShell is the one layer with no compiler and no validator of its own,
   and it is the layer that will run unattended at first boot with nobody watching. Static
   analysis is the only safety net it gets before a proof run.
   **How:** `Invoke-ScriptAnalyzer -Path powershell/ -Recurse -Severity Error,Warning`.
   Settings file pinning the rules, so a new analyzer release cannot turn the build red on
   its own.

   Notes:

6. [ ] CI job: secret scanning on every push
   **What:** gitleaks over the full history and every new commit, failing the build on a
   hit.
   **Why:** PLAN.md's secrets decision says no credential ever lands in git, and the repo
   is public, so that rule needs a machine enforcing it rather than discipline. A leaked
   Proxmox token in a public portfolio repo is the single worst outcome available here.
   **How:** the gitleaks action in the same workflow, scanning full history on push to
   `main`. Confirm `.gitignore` already covers tfvars and pkrvars — it does — and that
   the scan would still catch a file committed with `-f`.

   Notes:

7. [ ] CI job: documentation link check
   **What:** a link checker over every markdown file, failing on a dead relative link.
   **Why:** docs are a deliverable per PLAN.md, the README is the reviewer's entry point,
   and it links out to seven files. A broken link there is the cheapest possible bad
   impression.
   **How:** lychee or markdown-link-check over `**/*.md`, relative links only, external
   URLs excluded so a third-party outage cannot fail the build.

   Notes:

8. [ ] Prove the harness actually fails
   **What:** a throwaway branch that breaks each check in turn — bad HCL, an unformatted
   file, a PowerShell analyzer violation, a fake credential, a dead link — confirming each
   job goes red, then deleted without merging.
   **Why:** an untested test harness is worth nothing, and this one is the project's only
   evidence of correctness. A job that is silently skipping or passing on an empty
   directory looks identical to a working one until the moment it matters.
   **How:** one commit per broken check on a branch, screenshot or note each red run, then
   delete the branch. Record in the Notes which check caught what.

   Notes:

9. [ ] Add the CI badge and an execution status section to README.md
   **What:** the workflow status badge at the top, and a short section stating exactly
   what is validated and what has never been run on real hardware.
   **Why:** PLAN.md requires the execution status to be stated plainly. The badge and that
   paragraph together are what stop a reviewer from either over-reading the repo as a
   running system or dismissing it as untested.
   **How:** badge from the Actions workflow, then a short section listing what CI checks
   and one sentence saying the lab has not yet been applied to a host. Keep the wording
   ready to update when the proof run lands.

   Notes:

10. [ ] Record the CI contract in CLAUDE.md and docs/conventions.md
    **What:** the rule that every layer must stay fmt-clean and validate-clean, that CI
    holds no secrets, and the command each check runs.
    **Why:** Milestones 3 to 6 are written against this harness. Whoever writes that code
    needs to know the checks exist and what they enforce, without reading the workflow
    file to find out.
    **How:** a short Validation section in CLAUDE.md with the commands; the conventions
    doc gets the formatting and pinning rules. Both stay short — CLAUDE.md is loaded every
    session.

    Notes:

## Milestone 3: Packer builds the Windows Server 2025 template

<!-- Not planned yet. Ends at validated, not built — see the plan revision above. -->

## Milestone 4: OPNsense routes the lab VLANs

<!-- Not planned yet. -->

## Milestone 5: Terraform provisions DC01, SRV01 and CL01 from the template

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
