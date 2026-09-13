# SI Portfolio Lab

## Goal

A small company network built entirely as code — Proxmox host, Windows Server 2025
image, VMs, Active Directory, and a routed multi-VLAN network — that can be torn
down and rebuilt from the repo. It exists to support a career switch from
Anwendungsentwicklung to Systemintegration.

The reader is a hiring manager, not a customer. Success is a reviewer understanding
what was built and why in five minutes. No host exists to run it on yet, so until one
does the proof is that every layer validates in CI on every push — see the execution
status decision below.

## Not in scope

- Not a product. No users, no income, no support.
- No high availability, no Proxmox clustering, no failover.
- No cloud and no hybrid identity (no Entra ID / Azure AD Connect).
- No monitoring, logging or backup stack in the first pass.
- No sysprep / image generalization.
- No host to run on. The code must not assume one specific machine — see the
  execution status decision below.
- Nothing in this lab runs on the development machine. It is a VMware guest with no
  nested virtualization, 2 GB of RAM and a full disk.

## Stack

| Part | Choice |
| --- | --- |
| Hypervisor | Proxmox VE 9.2 — target platform, no host available yet |
| Validation | GitHub Actions — fmt, validate, lint and secret scanning on every push |
| Image build | Packer — two base images, Windows Server 2025 and Windows 11, with VirtIO drivers and WinRM |
| Provisioning | Terraform with the bpg/proxmox provider |
| OS configuration | Windows PowerShell 5.1 |
| Router / firewall | OPNsense |
| Guests | Windows Server 2025 (DC01, SRV01), Windows 11 (CL01) |
| Directory | Active Directory Domain Services, DNS, DHCP, Group Policy |
| Docs | Markdown in-repo, diagrams as Mermaid |
| VCS | Git, single repository |

## Decisions

<!-- Index generated from the headings below. Decisions are never reordered or
     retitled: the history is the point. Append new ones at the end and add a row. -->

| # | Decision |
| --- | --- |
| 1 | [Topology is domain controller, member server, client and firewall](#topology-is-domain-controller-member-server-client-and-firewall) |
| 2 | [Active Directory forest root is ad.silab.internal, NetBIOS SILAB](#active-directory-forest-root-is-adsilabinternal-netbios-silab) |
| 3 | [Bake the image with Packer but do not sysprep it](#bake-the-image-with-packer-but-do-not-sysprep-it) |
| 4 | [Terraform uses the bpg/proxmox provider](#terraform-uses-the-bpgproxmox-provider) |
| 5 | [OS configuration is Windows PowerShell 5.1, not PowerShell 7](#os-configuration-is-windows-powershell-51-not-powershell-7) |
| 6 | [OPNsense as the lab router](#opnsense-as-the-lab-router) |
| 7 | [Documentation is a deliverable, not an afterthought](#documentation-is-a-deliverable-not-an-afterthought) |
| 8 | [One repository for all four layers](#one-repository-for-all-four-layers) |
| 9 | [OPNsense is configured via the browningluke/opnsense Terraform provider](#opnsense-is-configured-via-the-browninglukeopnsense-terraform-provider) |
| 10 | [Secrets are env vars + gitignored local var files, handed to PowerShell through Terraform](#secrets-are-env-vars--gitignored-local-var-files-handed-to-powershell-through-terraform) |
| 11 | [The lab is authored and validated now, and executed only if a host appears](#the-lab-is-authored-and-validated-now-and-executed-only-if-a-host-appears) |
| 12 | [CI is the test harness, and it validates but never applies](#ci-is-the-test-harness-and-it-validates-but-never-applies) |
| 13 | [The repository is public on GitHub](#the-repository-is-public-on-github) |
| 14 | [Execution status is stated plainly in the README](#execution-status-is-stated-plainly-in-the-readme) |
| 15 | [The proof run is rented hourly bare metal, not purchased hardware](#the-proof-run-is-rented-hourly-bare-metal-not-purchased-hardware) |
| 16 | [Two Packer templates, Windows Server 2025 and Windows 11](#two-packer-templates-windows-server-2025-and-windows-11) |
| 17 | [Both images are built in German (de-DE) throughout](#both-images-are-built-in-german-de-de-throughout) |
| 18 | [Windows Server uses Desktop Experience, not Server Core](#windows-server-uses-desktop-experience-not-server-core) |
| 19 | [Windows 11 gets its local account directly in the answer file, not via a BypassNRO trick](#windows-11-gets-its-local-account-directly-in-the-answer-file-not-via-a-bypassnro-trick) |
| 20 | [The OPNsense bootstrap is manual, and the boundary is stated in the runbook](#the-opnsense-bootstrap-is-manual-and-the-boundary-is-stated-in-the-runbook) |
| 21 | [The OPNsense VM is defined in terraform/ with every other VM](#the-opnsense-vm-is-defined-in-terraform-with-every-other-vm) |
| 22 | [One milestone is one branch, one task is one commit, one PR per milestone](#one-milestone-is-one-branch-one-task-is-one-commit-one-pr-per-milestone) |
| 23 | [Inter-VLAN traffic is least privilege, with a reason on every rule](#inter-vlan-traffic-is-least-privilege-with-a-reason-on-every-rule) |
| 24 | [The manual/code boundary is interface assignment and addressing, not VLANs](#the-manualcode-boundary-is-interface-assignment-and-addressing-not-vlans) |
| 25 | [Guests reach their first address by DHCP reservation, then PowerShell makes it static](#guests-reach-their-first-address-by-dhcp-reservation-then-powershell-makes-it-static) |
| 26 | [DHCP stays with OPNsense; PowerShell never runs a DHCP server](#dhcp-stays-with-opnsense-powershell-never-runs-a-dhcp-server) |
| 27 | [The guest drives itself across reboots; Terraform fires once and stops](#the-guest-drives-itself-across-reboots-terraform-fires-once-and-stops) |
| 28 | [Credentials never outlive the phase that needs them](#credentials-never-outlive-the-phase-that-needs-them) |
| 29 | [The Safe Mode recovery password is its own Terraform variable](#the-safe-mode-recovery-password-is-its-own-terraform-variable) |
| 30 | [The repository stays in English throughout](#the-repository-stays-in-english-throughout) |
| 31 | [The reader-facing surface is a narrative walkthrough plus an explicit limitations section](#the-reader-facing-surface-is-a-narrative-walkthrough-plus-an-explicit-limitations-section) |
| 32 | [Every credential lives in one gitignored .env at the repository root](#every-credential-lives-in-one-gitignored-env-at-the-repository-root) |
| 33 | [OPNsense ships as a Packer template, configured via its own live-image importer](#opnsense-ships-as-a-packer-template-configured-via-its-own-live-image-importer) |
| 34 | [The Proxmox host installs itself from an answer file; its tokens travel to the operator over SSH](#the-proxmox-host-installs-itself-from-an-answer-file-its-tokens-travel-to-the-operator-over-ssh) |
| 35 | [Zero-touch deployment supersedes the manual OPNsense bootstrap and hardens the manual/code boundary finding](#zero-touch-deployment-supersedes-the-manual-opnsense-bootstrap-and-hardens-the-manualcode-boundary-finding) |
| 36 | [SPIKE: the host's network exists in stages — provider DHCP, then a build network, then VLAN 10](#spike-the-hosts-network-exists-in-stages--provider-dhcp-then-a-build-network-then-vlan-10) |
| 37 | [SPIKE: Terraform starts each Bootstrap script and lets go; a bash poll loop on the host watches phase.json](#spike-terraform-starts-each-bootstrap-script-and-lets-go-a-bash-poll-loop-on-the-host-watches-phasejson) |
| 38 | [The Packer/Terraform build runs on the Proxmox host itself; deploy.sh is a thin SSH wrapper around it](#the-packerterraform-build-runs-on-the-proxmox-host-itself-deploysh-is-a-thin-ssh-wrapper-around-it) |

### Topology is domain controller, member server, client and firewall

Why: the smallest set that proves the whole story end to end — a routed network with
VLANs, a domain, a machine joining it, and a policy actually landing on a client.
Rejected: a single domain controller — the GPOs would be authored but never observed
applying, which is the first thing a reviewer would ask about.
Rejected: two domain controllers for replication — shows one more feature but loses
the client, and with it the visible proof that the domain works.

### Active Directory forest root is ad.silab.internal, NetBIOS SILAB

Why: .internal is reserved by ICANN for private use, so it can never collide with a
real registration, and it does not overlap with mDNS.
Rejected: lab.local — .local is mDNS and collides on Linux and macOS clients;
Microsoft has advised against it for years, so using it would read as a mistake.

### Bake the image with Packer but do not sysprep it

Why: every clone gets its hostname and address from PowerShell at first boot anyway.
Sysprep adds a long unattended pass and a whole class of failures that has nothing to
do with the skills being shown.
Rejected: sysprep / generalize — the correct answer for production imaging, and the
honest tradeoff is that clones share a machine SID. That is harmless here because
domain join issues a fresh machine account per host.

### Terraform uses the bpg/proxmox provider

Why: actively maintained, tracks the Proxmox 8 and 9 APIs, and covers VM cloning and
disk and network settings properly.
Rejected: Telmate/proxmox — releases lag far behind Proxmox itself and it has
long-standing state drift problems on clone operations.

### OS configuration is Windows PowerShell 5.1, not PowerShell 7

Why: 5.1 is in the box on Windows Server 2025 and the ActiveDirectory, DhcpServer and
GroupPolicy modules are native to it. Nothing has to be installed before config runs.
Rejected: PowerShell 7 — would have to be baked into the image or bootstrapped on
every guest, for language features this project does not need.

### OPNsense as the lab router

Why: it has a documented REST API and a single importable config file, so the network
layer can be version-controlled like everything else.
Rejected: pfSense CE — comparable as a firewall, but API access depends on a
third-party package, which undercuts the point of the project.
Rejected: a Linux VM with nftables — more code to write and a weaker portfolio signal
than a real firewall appliance.

### Documentation is a deliverable, not an afterthought

Why: the reader skims; most will never clone the repo. The reasoning is the most
interesting output and it is the first thing forgotten once the code works.
Rejected: code first, write it up at the end — by then the reasons for the decisions
are gone.

### One repository for all four layers

Why: the layers only make sense together, and a reviewer should follow one link and
find one entry point.
Rejected: a repository per layer — three links to follow and no obvious starting
point.

### OPNsense is configured via the browningluke/opnsense Terraform provider

Why: it wraps OPNsense's own REST API — which has full coverage of what this lab
needs (VLAN interfaces, Kea DHCP, firewall filter rules, NAT, aliases) — and keeps
the whole lab, firewall included, under one `terraform apply` instead of a second,
bespoke automation mechanism living next to Terraform.
Accepted risk: the provider is pre-1.0 and explicitly makes no stability guarantee.
Pin an exact provider version in `terraform/` and expect to revisit this decision if
a version bump breaks a resource.
Rejected: config.xml import — a whole-file replace with no per-resource diff, and
brittle across OPNsense version upgrades since the exported schema can shift.
Rejected: hand-rolled scripts against the raw REST API — the API itself has full
coverage, but this would be a second automation layer when Terraform already owns
provisioning for every other layer in the repo.

### Secrets are env vars + gitignored local var files, handed to PowerShell through Terraform

Why: one operator, one machine — nothing here is ever read by a second user or a CI
system, so a secrets manager is a service to install, expose and patch for three
secrets. Terraform (`TF_VAR_*` + gitignored `terraform.tfvars`, `sensitive = true`)
and Packer (`PKR_VAR_*` + gitignored `*.pkrvars.hcl`) already support this natively.
PowerShell has no equivalent of its own, since it runs inside the guest — Terraform
passes the domain admin and local admin passwords to it as `sensitive` variables,
inline parameters to its WinRM provisioner at apply time. The password exists only
in the Terraform run and the target VM's command execution — never written to a file
in the repo or left on disk in the guest.
Rejected: a secrets manager (e.g. Vault) — infrastructure to run and maintain, for a
problem three gitignored files and two env-var conventions already solve.
Rejected: baking passwords into the Packer image or its unattend file — the image is
shared across every clone (see the no-sysprep decision above) and must stay free of
anything machine- or environment-specific, secrets included.
Replaced by: Every credential lives in one gitignored .env at the repository root. Only
the storage half is superseded — the handoff to PowerShell through Terraform's WinRM
provisioner, and the rule that nothing is written to a file in the repo or left on disk
in the guest, both still stand.

### The lab is authored and validated now, and executed only if a host appears

Why: there is no Proxmox host, and there may never be one. The development machine
cannot stand in — it is a VMware guest with no nested virtualization, roughly 300 MB
of free RAM and a full disk, so not even a single nested VM will boot on it. A plan
that blocks on hardware produces nothing, so the repo is built to be complete and
reviewable without ever being applied, and applying it becomes a separate optional
milestone.
Rejected: pause until hardware exists — the portfolio piece would stay a folder of
markdown for an unbounded amount of time, which defeats its purpose.
Rejected: pivot to Samba AD in containers so it runs on this machine — it would
execute, but it discards Proxmox, Windows Server, Packer and Group Policy, which are
exactly the skills the career switch is meant to show. That is a different project.

### CI is the test harness, and it validates but never applies

Why: no layer can be run during development, so the only available feedback is static
— `terraform fmt` and `validate`, `packer fmt` and `validate`, PSScriptAnalyzer, and
secret scanning, on every push. It runs in GitHub Actions rather than locally because
the development machine has about 1 GB of disk free, which does not fit the Terraform
and Packer binaries or their provider caches.
This does not weaken the secrets decision above: CI only ever validates, so it holds
no credentials and no repository secrets are configured. If that ever changes, the
secrets decision has to be revisited first.
Rejected: installing the CLIs locally — roughly 600 MB against 1.1 GB free on a disk
already at 98%.
Rejected: running the tooling in Docker images — same disk, since the images land in
`/var/lib/docker` on the same full filesystem.

### The repository is public on GitHub

Why: the deliverable is a link on a job application. A public repo with a passing CI
badge is the artifact a hiring manager can open in one click, which is the stated
measure of success.
Rejected: a private repo shared on request — same code, but it adds a step between
the reader and the work at exactly the moment their attention is shortest.

### Execution status is stated plainly in the README

Why: the repo will describe a working network it has not yet run. Letting a reader
infer it has been applied would be a misrepresentation, and it is the kind a
technical interviewer finds in the first five minutes. Saying so directly turns a
weakness into evidence of judgement.
How: the README states what is validated and what is unexecuted, and the wording gets
updated the moment a proof run lands.
Rejected: staying quiet about it and showing only the architecture — the risk is
being read as dishonest rather than as unfinished.

### The proof run is rented hourly bare metal, not purchased hardware

Why: it converts "this should work" into "this ran" for roughly the price of a meal,
with no hardware to buy, house or keep. Hourly-billed bare metal from a provider such
as Scaleway or Hetzner can take a Proxmox install, run the whole build once, be
captured as evidence, and be destroyed the same weekend.
Note: this is a capstone, not a dependency. Every milestone before it stands on its
own, and the repo is a complete portfolio piece if it never happens.
Note, corrected by Milestone 9's second SPIKE (2026-09-12): Hetzner and Scaleway were
named here as interchangeable hourly examples without checking either provider's actual
billing terms. Hetzner's real dedicated-hardware line (Server Auction/Robot) bills
monthly, not hourly — only its virtualized Cloud product is hourly, which is exactly the
kind of instance this decision's own "ordinary cloud VMs" rejection below rules out.
Scaleway's Elastic Metal is genuinely hourly, genuinely bare metal, and lists Proxmox VE
as a catalog image. See
[The Proxmox host installs itself from an answer file; its tokens travel to the operator
over SSH](#the-proxmox-host-installs-itself-from-an-answer-file-its-tokens-travel-to-the-operator-over-ssh).
Milestone 8 task 1 still owns the final provider and product choice.
Rejected: buying a host now — the largest cost in the project for a benefit that
rented metal delivers for a few euros.
Rejected: nesting Proxmox on the existing homelab host — not available at the moment.
Worth revisiting if that changes, since it would make the proof run free.
Rejected: ordinary cloud VMs — nested virtualization is either unavailable or
unreliable on shared-tenancy instances, which is precisely what this workload needs.

### Two Packer templates, Windows Server 2025 and Windows 11

Why: CL01 is a Windows 11 workstation in every design document, and the client half
of the demonstration — a workstation joining the domain and visibly receiving a GPO —
is the part a reviewer asks about first. Windows 11 needs its own installation media,
a TPM 2.0 device and Secure Boot, so it cannot be cloned from a Server template. The
two builds share their VirtIO injection, WinRM setup and provisioners, so the second
one is mostly a different ISO and a different firmware shape.
Note: this supersedes the "single template" wording carried in the `packer-windows`
skill, which was written before the client was thought through.
Rejected: one Server 2025 template for all three guests — the simplest possible build,
but it makes the client fictional and a reviewer would read it as avoiding the work.
Rejected: Windows 10 LTSC for the client — no TPM or Secure Boot requirement and
therefore an easier build, but it demonstrates an operating system past end of support.
Rejected: deferring the Windows 11 template to a later milestone — the two builds share
most of their structure, so splitting them means writing the same answer file and
provisioner logic twice, weeks apart, with nothing runnable in between to compare.

### Both images are built in German (de-DE) throughout

Why: this portfolio targets the German job market, and every piece of visual evidence
the project produces is a screenshot. A domain that looks like a German company network
is more convincing in that screenshot than a locale-agnostic one, and locale is baked
into the image at install time — changing it later means a rebuild, not a setting.
Accepted cost: Windows errors come back in German, which makes them measurably harder
to search for while debugging. Worth it, given the audience.
Rejected: en-US throughout — every error message matches the online documentation
exactly, which is the easier build, but the lab then reads as generic.
Rejected: an en-US system with a German keyboard and timezone — a common real compromise
in German companies, but it splits the difference and gives up the authenticity that was
the whole reason for choosing German.

### Windows Server uses Desktop Experience, not Server Core

Why: `docs/ad-design.md` already names screenshots as the visible proof that the domain
works, and Active Directory Users and Computers and the Group Policy Management Console
are what produce them. Those consoles are also instantly recognisable to any reviewer
who has run a Windows domain.
Accepted cost: a substantially larger image and more patching than Core, and it is not
what a modern production build would choose. Say so in the README rather than let it
look unconsidered.
Rejected: Server Core — smaller, faster to patch and closer to current practice, but
every piece of visual evidence would then have to come from a remote console, making the
proof depend on the client being up first.
Rejected: Core for DC01 and Desktop Experience for SRV01 — demonstrates both, at the
cost of two server variants to maintain in the layer that is hardest to debug with no
hardware to test on.

### Windows 11 gets its local account directly in the answer file, not via a BypassNRO trick

Why: researched live (2026-09-11) because Microsoft has spent 2025 tightening the
interactive OOBE — the manual `oobe\bypassnro` command and the `ms-cxh:localonly` URI
were both blocked in Insider builds during 2025, and reports on retail 25H2 builds
are inconsistent about whether either still works. None of that matters here: those
are workarounds for a *human* clicking through Setup. An `autounattend.xml` never
sees that screen at all — putting the account directly in
`Microsoft-Windows-Shell-Setup/UserAccounts/LocalAccounts` plus
`HideOnlineAccountScreens`/`HideWirelessSetupInOOBE`/`ProtectYourPC` in `oobeSystem`
is the same mechanism OEM and enterprise deployment tooling (MDT, Autopilot) has
always used, and every 2026 source confirms it still works — Microsoft cannot break
it without breaking its own enterprise deployment story.
Confirmed separately: the VM gets a real TPM 2.0 and Secure Boot (see the Desktop
Experience decision's sibling, below), so no hardware-check bypass registry keys
(`BypassTPMCheck`, `BypassSecureBootCheck`, etc.) are needed at all — those exist for
the "install on hardware that doesn't qualify" case, not this one.
Residual unknown: the exact image-index name for Windows 11 Pro on the German ISO is
assumed to be the unlocalized string `"Windows 11 Pro"` (WIM image names aren't
localized), but this is unverified against the real ISO, since there is no host to
mount it on yet. Confirm before the Milestone 8 proof run, not before.
Rejected: the registry-based `BypassNRO` route — it is documented as increasingly
unreliable across 2025-2026 builds and it solves a problem (the interactive OOBE
screen) that a fully unattended answer file never encounters in the first place.
Rejected: a Microsoft Entra / cloud-account first boot, converted to local after —
adds a network dependency and an extra provisioner step to undo work Setup just did,
for a build that already has WinRM and a provisioner chain to create the account
correctly the first time.

### The OPNsense bootstrap is manual, and the boundary is stated in the runbook

Why: the Terraform provider talks to OPNsense's REST API, so something has to install
the appliance, assign its interfaces and enable that API before any code can run. That
is a one-time appliance install, and automating it would mean reintroducing the
config.xml mechanism already rejected for the main configuration, in a form nobody can
test until a host exists. Real deployments install an appliance by hand too.
How: `docs/runbook.md` splits section 3 into a manual half and a code half, and says
exactly which settings belong to each. Anything that can be code, is code.
Rejected: seeding a config.xml at first boot — fully hands-off, but it brings back a
mechanism this project rejected on its merits, and it would be unverifiable until the
proof run.
Rejected: calling the whole firewall manual — it would leave the layer with the most
interesting content, the rule set, outside the repo.
Replaced by: [Zero-touch deployment supersedes the manual OPNsense bootstrap and hardens
the manual/code boundary finding](#zero-touch-deployment-supersedes-the-manual-opnsense-bootstrap-and-hardens-the-manualcode-boundary-finding).
The rejection of a seeded config.xml above was right about the mechanism this project
had rejected on its merits at the time — a file dropped at first boot, unversioned and
outside git. It was wrong to assume that was the only shape a seeded config could take.
A config template that lives in the repository, is rendered from `docs/network-design.md`
and `.env` at build time, and is baked into a Packer template the same way every other
image in this project is, is not that mechanism — it is the same discipline this project
already applies to the two Windows answer files.

### The OPNsense VM is defined in terraform/ with every other VM

Why: the firewall is a Proxmox VM like the other three, and the rebuild-from-repo claim
only holds if it is in code. Keeping one Proxmox root means one place that knows about
VM IDs, datastores and VLAN tags. The `opnsense/` root stays what its skill says it is —
configuration of a running firewall, with its own state and its own lifecycle.
Consequence: `terraform/` is applied in two stages. The firewall VM comes up and is
bootstrapped before the Windows VMs are worth starting, because until it routes there is
no gateway, no DHCP and no DNS path. Milestone 4 therefore also scaffolds the
`terraform/` root, and Milestone 5 adds the three Windows guests to it.
Rejected: a third Terraform root for just the firewall VM — makes the ordering visible in
the directory layout, at the cost of three states to manage for four VMs.
Rejected: creating it by hand in the Proxmox UI — the install is manual anyway, but the
VM definition is exactly the part that should not be, since it carries the VLAN tags and
the hardware shape.

### One milestone is one branch, one task is one commit, one PR per milestone

Why: `TASKS.md` already breaks the work into task-sized pieces, and a commit per task
makes the git history and the task list the same list — each commit reviewable on its own
against the task's `Accept:` line. A 40-file milestone diff is not reviewable; ten commits
behind one PR are. It also gives the repo a visible PR history, which is part of what a
hiring manager reads.
How: branch from `main` when a milestone's first task starts, named per
`docs/conventions.md`. One PR per milestone, not per task — reviewers step through it
commit by commit. Adopted at Milestone 4; Milestones 1–3 landed as direct commits to
`main` and are left as they are.
Rejected: a PR per task — ten PRs per milestone for a solo project, each one merged by its
own author minutes after opening, which is ceremony rather than review.
Rejected: continuing to commit straight to `main` — it worked while the repo was documents
only, but from Milestone 4 on each milestone is a coherent code change that is worth
reading as one unit.

### Inter-VLAN traffic is least privilege, with a reason on every rule

Why: three VLANs that can all reach each other are an organisational label, not a
security boundary, and a reviewer reads an unrestricted allow rule as segmentation
theatre. Least privilege is also the posture the Systemintegration role being applied for
actually has to implement.
How: default deny between VLANs. Clients reach DC01 for exactly the services a domain
member needs and nothing else. The Management VLAN is reachable from no other VLAN. Each
rule carries a description saying what it is for, per the `terraform-opnsense` skill.
Accepted cost: the largest rule set in the project, and the layer most likely to be
subtly wrong in a way static validation cannot catch. `docs/network-design.md` carries
the policy so the rules implement a written spec rather than accumulating.
Rejected: VLAN isolation with broad allows between Clients and Servers — far fewer rules,
but it gives up the part that demonstrates the skill.
Rejected: filtering only at the WAN edge — a flat network with extra steps.

### The manual/code boundary is interface assignment and addressing, not VLANs

Why: checked the pinned browningluke/opnsense 0.26.0 resource list directly (47
resources, not the provider's latest docs) rather than assume. `opnsense_interfaces_vlan`
creates a VLAN's tag/parent/device — that part is code. Nothing in 0.26.0 assigns a raw
interface (physical NIC or VLAN device) to a logical slot (WAN/LAN/OPTx) or sets its IP
address; `interfaces_vip` is virtual IPs (CARP-style), not primary addressing, and no
other resource covers it either. DHCP (Kea) and firewall (filter/NAT/aliases) are both
fully covered.
How: the manual half (runbook 3a) is the ISO install, assigning the two physical NICs
(WAN uplink, VLAN trunk), enabling the API and creating a key, then — after `terraform
apply` creates the three VLAN devices — manually assigning each to an interface slot and
giving it its static address from `docs/network-design.md`. The code half (3b) is the
VLAN tag resources, the Kea scope, and every firewall rule.
Consequence: `terraform apply` for `opnsense/` cannot be the last step for a VLAN to
become usable — each of the three VLAN devices it creates still needs one manual
assignment+address step before DHCP or firewall rules on it mean anything. State this
order explicitly in the runbook, not just the split.
Rejected: waiting for a future provider version that might add interface assignment —
pins the milestone to an upstream release with no date freely chosen by this project.
Amended by [Zero-touch deployment supersedes the manual OPNsense bootstrap and hardens
the manual/code boundary finding](#zero-touch-deployment-supersedes-the-manual-opnsense-bootstrap-and-hardens-the-manualcode-boundary-finding):
the finding above still holds exactly as checked — no resource in the pinned provider
assigns an interface or sets its address, and none has appeared since. Only the
consequence changes. What used to mean a person doing that one step by hand after every
`terraform apply` now means a Packer template that boots with the assignment already
made, because the same live-image importer that solves the OPNsense bootstrap (see the
replacement above) sets interface assignment and addressing too, before the installed
system's own first boot ever reaches the point of asking. The `opnsense/` root still
owns everything the API actually reaches — DHCP, firewall, NAT, aliases — unchanged.
Rejected: treating the whole `opnsense/` root as not worth it since it can't reach 100%
automation — the DHCP and firewall layer is real, substantial code either way.

### Guests reach their first address by DHCP reservation, then PowerShell makes it static

Why: a freshly cloned guest has no address — the templates ship without one on purpose,
since identity is set at first boot. But Terraform has to reach the guest over WinRM to
do that setting, and the Servers VLAN deliberately has no DHCP. Without something
closing that loop, DC01 boots unreachable and the whole handoff to `powershell/` has
nowhere to start.
How: Terraform pins an explicit MAC on every guest NIC, and OPNsense hands that MAC
exactly the address the static table already documents. The Servers VLAN scope has no
dynamic pool at all — only reservations — so an unknown machine still gets nothing, and
an address cannot drift away from `docs/network-design.md`. PowerShell then writes the
same address statically, because a domain controller must not depend on DHCP to come
back after a reboot. The reservation is a bootstrap crutch, not the running state.
Rejected: cloudbase-init in the image — the standard answer, and it removes the DHCP
dependency entirely, but it reopens a finished Packer milestone, forces a v2 template,
and adds software to an image whose minimalism is itself a decision.
Rejected: generating a per-VM config ISO that a baked-in scheduled task reads — self
contained, but it is custom machinery and still needs an image change for the task.
Rejected: leaving the Servers VLAN with a normal dynamic pool — simpler, but it puts two
authorities on the same addresses and invites exactly the drift the no-DHCP rule was
written to prevent.

### DHCP stays with OPNsense; PowerShell never runs a DHCP server

Why: the original sketch of this project listed DHCP alongside AD DS and DNS as
PowerShell's job, and the Milestone 6 heading carried that wording forward. The network
design then gave DHCP to Kea on OPNsense, and Milestone 4 built it. One DHCP authority in
a lab this size is the whole argument — two would be a design a reviewer questions.
Rejected: the Windows DHCP Server role on DC01, authorised in Active Directory — a
genuine Systemintegration skill and a stronger Windows showcase, but it undoes working
configuration from a finished milestone and adds a DHCP relay hop across the VLAN
boundary for no functional gain.
Rejected: splitting it by VLAN, Kea for the server reservations and Windows for the
clients — demonstrates both, at the cost of two authorities over one small address plan.

### The guest drives itself across reboots; Terraform fires once and stops

Why: promoting a domain controller reboots the machine and drops the WinRM session, and
so does renaming a host. The `terraform-proxmox` skill already fixes that Terraform's
last act is bringing the VM up with the first-boot PowerShell in place, so the sequencing
has to live inside the guest. A script that records which phase it reached and
re-registers itself to continue after each reboot is also the version that still works
when a human runs it by hand during a proof run, with no Terraform involved.
How: a phase marker written to disk, a scheduled task registered on the first run and
removed when the last phase completes. Every phase is idempotent, per AGENTS.md, so a
retry after a failure re-runs the phase rather than needing a clean VM.
Rejected: Terraform orchestrating one remote-exec per reboot boundary — the sequence
would be visible in the plan, but it puts Active Directory orchestration into Terraform,
which the skill forbids outright, and it makes a manual re-run impossible without running
Terraform against a live Proxmox host.

### Credentials never outlive the phase that needs them

Why: phases resume after a reboot through a scheduled task, but the passwords Terraform
passes arrive as command-line arguments and are gone the moment the machine restarts.
Persisting them would mean writing secrets to the guest's disk, which the secrets
decision above forbids outright.
How: phase ordering is the mechanism, not a credential store. Anything needing a
credential happens before the reboot that loses it. On DC01 the promotion phase consumes
the recovery password and then reboots; every phase after it runs as SYSTEM on a domain
controller, which already holds the directory rights to create OUs, groups and GPOs. On
SRV01 and CL01 the join consumes the domain credential and then reboots; nothing after
it needs one.
Consequence: a phase that turns out to need a credential after a reboot is a design
error, not a reason to add a credential store. Reorder the phases instead.
Rejected: DPAPI-encrypted credentials written to the guest and deleted when the last
phase completes — it works regardless of ordering, but it contradicts the secrets
decision and leaves a window where secrets sit on disk in the guest.

### The Safe Mode recovery password is its own Terraform variable

Why: `Install-ADDSForest` requires a directory restore password, and Terraform currently
passes only a local administrator and a domain administrator password. The restore
credential exists for a different purpose and a different lifetime than either, so it
gets its own `sensitive` variable, passed only to DC01.
Rejected: reusing the domain administrator password — no Terraform change needed, and no
operator of this lab will ever perform a directory restore, but it quietly merges two
credentials that exist for unrelated reasons, which is the kind of shortcut a reviewer
notices and asks about.

### The repository stays in English throughout

Why: English is the convention for infrastructure code, keeps every identifier, comment
and error message consistent with the tools themselves, and leaves one set of documents
to maintain rather than two that drift.
Note: this sits deliberately alongside the German image decision above. The machines are
German because the lab imitates a German company network; the repository is English
because it is engineering documentation. They are answering different questions.
Rejected: an English repository with a German README as a second front door — the
strongest gesture toward the actual hiring audience, and cheap at one file, but it is a
file that silently goes stale the moment the English one changes.
Rejected: German throughout — the clearest signal for a German employer, at the cost of
cutting off any English-reading reviewer and rewriting every design document.

### The reader-facing surface is a narrative walkthrough plus an explicit limitations section

Why: the repository already has reference material and operational material, and neither
tells a story. The design documents say what the network is, the runbook says what to
type, but nothing traces one machine from blank ISO to domain-joined client with a policy
applied. That trace is what shows understanding rather than configuration, and it is what
a reviewer with three minutes can actually absorb.
The limitations section is the same argument from the other side: naming what the lab
deliberately does not do — no high availability, no backup, no monitoring, one site,
never applied to hardware — before a reviewer finds it reads as scope control rather than
oversight. It pairs with the execution status section already in the README.
Rejected: a digest of the most revealing decisions pulled to the front — cheaper, and
`PLAN.md` is genuinely too long to skim at 29 entries, but a list of conclusions without
the thread connecting them is less convincing than the thread.
Rejected: tightening the README and stopping there — the fastest option, and the stale
claims have to be fixed regardless, but it adds nothing a reader did not already have.

### Every credential lives in one gitignored .env at the repository root

Why: credentials were previously spread across shell variables set by hand and two
gitignored var files, with no single place to look and no single place to fill in. An
operator starting the proof run had to work out which variables mattered from three
example files and two runbook tables. One file, copied from a committed template, is the
difference between a ten-minute start and an hour of hunting — and the proof run is
billed by the hour.
How: `example.env` is committed and lists every variable with a placeholder and what it
is for. `.env` is gitignored and holds the real values, loaded once with
`set -a; . ./.env; set +a` before any tool runs. Each layer's `example.tfvars` and
`example.pkrvars.hcl` keeps only non-secret tunables — node name, datastores, VLAN IDs,
ISO filenames — so no file that is in git has a place for a credential to be typed by
mistake.
Note: this supersedes only where secrets are stored. PowerShell still receives them as
inline parameters from Terraform's WinRM provisioner, and nothing is written to a file
on the guest.
Accepted cost: one file now concentrates every credential, so a single mistake exposes
all of them rather than one layer's worth. `.gitignore` carries an explicit
`!example.env` negation, because `*.env` would otherwise swallow the committed template
and leave a reader with nothing to copy — a trap worth naming, since the failure is
silent.
Rejected: keeping credentials in the shell only, never on disk — genuinely safer, but it
means retyping them or leaving them in shell history, and there is no template to hand
anyone.
Rejected: one `.env` per layer — a smaller blast radius per file, but the Proxmox
endpoint and the local administrator password are shared between layers and would have
to be written twice, which is how two copies drift apart.

### OPNsense ships as a Packer template, configured via its own live-image importer

Why: researched live (2026-09-12) because the manual/code boundary decision below found
no API to assign or address an interface — but that is a fact about the *running* REST
API, not about the installer, and the installer turns out to have a real, documented
route around it. OPNsense's live image looks for a second FAT/FAT32-formatted volume
carrying an unencrypted `/conf/config.xml`; at "Press any key to start the configuration
importer" it loads that file — interfaces assigned, VLAN devices created, the API
enabled, a user's key already present — before the installer ever touches the target
disk, so the installed system inherits it whole. This is OPNsense's own mechanism for
scripted and appliance deployment, not a workaround improvised for this project, and its
own issue tracker describes it in exactly those terms.
The remaining install steps — keymap, filesystem choice, disk selection, the "Last
Chance!" format confirmation, swap, root password, reboot — are a linear `bsdinstall`
dialog sequence with no branching once the target disk is fixed to one device, the same
shape of keystroke automation `boot_command` already drives for both Windows answer
files, just against TUI dialogs instead of an XML file.
API keys live in `config.xml` as a plaintext `<key>` and a SHA-512-crypt (`$6$...`)
`<secret>` — the identical hash format `passwd` itself uses — so both the real secret and
its hash can be generated offline in `scripts/init-env.sh`, with only the hash ever
reaching a committed template.
Confirmed: `additional_iso_files`/`boot_command` already drive this exact shape of
installer automation twice, in `windows-server-2025.pkr.hcl` and `windows-11.pkr.hcl`;
the config-importer feature is real, current, and documented for unencrypted files; the
API secret's hash format is real, cross-checked against a live `config.xml` example, not
assumed from the passwd-hashing precedent alone.
Residual unknown, left for task 7 and the Milestone 8 proof run: OPNsense's own docs
describe the importer reading a FAT/FAT32 *USB* drive specifically, while Packer's
`additional_iso_files` produces an ISO9660 disc — whether the importer's device scan
also picks up an ISO9660 volume, or needs a small raw FAT32 disk image attached as an
extra virtual disk instead, is unconfirmed until there is a live image to test against.
Changes task 7's implementation only, not this decision. FreeBSD's `vtnet` interface
naming is PCI-slot order, confirmed stable — but only as long as Terraform's clone
declares the same two `network_device` blocks in the same order the template was built
with; that is a real constraint task 8 has to hold, not a risk to design around.
How: `packer/opnsense.pkr.hcl` drives the installer with `boot_command`;
`packer/files/config.xml` (task 6) carries the interface/VLAN/API configuration with
placeholders substituted from `PKR_VAR_*` at build time.
Correction, found while writing task 5 (2026-09-12): no rotate-after-build provisioner is
needed for the root password after all. OPNsense's own documentation confirms the
importer route makes `bsdinstall`'s own password prompt take its value from the imported
configuration — the installed system's root password already is whatever
`config.xml`'s `<passwd>` hash says, not a bootstrap value to change later.
Second correction, found while writing task 7 (2026-09-12) — the first correction above
was itself incomplete. OPNsense's install docs, read in full rather than summarized,
state plainly: once the importer runs, the live environment's own login prompt (the
`installer` user, which is what actually launches `bsdinstall`) requires *that same*
imported root password to log in *before* the installer ever starts — there is no
password-free path to it. That makes the Windows pattern the right one after all, for a
different reason than first assumed: `config.xml`'s `<passwd>` hash is a fixed,
non-secret bootstrap value (computed once, the same way the Windows answer files use a
fixed bootstrap string), typed by `boot_command` to clear that login gate; a `shell`
provisioner over SSH then rotates root's password to the real secret after install, the
same rotate-after-build pattern `rotate-admin-password.ps1` already uses. The API user's
`<secret>` hash is unaffected by any of this — it is never typed anywhere, only ever
read by the API, so it carries the real secret's hash from the start, generated offline
in `scripts/init-env.sh` exactly as originally planned.
Rejected: reproducing the configuration by sending keystrokes into OPNsense's post-install
console setup wizard (the LAN/WAN/OPT interface-name prompts) instead of the importer —
that wizard only assigns interfaces to physical/`vtnet` devices, has no path to create
VLAN devices or enable the API, and would still need a second automation mechanism for
everything it cannot reach.
Rejected: configuring OPNsense entirely after boot over SSH with a provisioner script —
works, but reimplements `config.xml` editing as ad hoc shell commands against a schema
this project already has full Terraform-resource coverage for (Milestone 4). The importer
route reuses `opnsense/`'s existing resources for everything the API can reach and only
needs a template for what only the installer can set.
### The Proxmox host installs itself from an answer file; its tokens travel to the operator over SSH

Amended by: [The Packer/Terraform build runs on the Proxmox host itself; deploy.sh is a thin SSH wrapper around it](#the-packerterraform-build-runs-on-the-proxmox-host-itself-deploysh-is-a-thin-ssh-wrapper-around-it).
The installer finding below stands untouched; the orchestration-location and
token-delivery finding it reaches at the end is superseded — WinRM cannot hop
through a jump host, so the build itself, not just its tokens, has to live on
the host.

Why: researched live (2026-09-12). `proxmox-auto-install-assistant prepare-iso` is real
and current, in the box since Proxmox VE 8.2: it embeds a TOML `answer.toml` — root
password, network configuration, target disk — plus an optional first-boot script into an
otherwise-stock installer ISO. The first-boot hook can be ordered `fully-up`, running only
once networking is live, which is exactly the point at which it can safely mint Proxmox
API tokens.
Rented bare metal, not the host installer, turned out to be the harder half of this
spike. Checked Hetzner and Scaleway — the two named in the proof-run decision — against
their actual billing pages rather than trusting the decision's own wording. Hetzner's
real bare-metal line (Server Auction/Robot) bills monthly with no hourly option; only
Hetzner Cloud is hourly, and Cloud instances are virtualized, which is exactly what this
project needs bare metal to avoid. Scaleway's Elastic Metal bills either hourly or
monthly with no commitment fee on the hourly plan, is genuine dedicated hardware, and its
Beryllium range lists Proxmox VE as a selectable catalog image outright. Scaleway
satisfies every constraint Milestone 8 task 1 has to check; Hetzner, as named, does not.
This corrects the proof-run decision's framing of the two as interchangeable, rather than
narrowing it — final product, rate and boot mechanism are still Milestone 8 task 1's job,
but it now starts from Scaleway rather than a coin flip.
Where orchestration runs was the other open question: an operator's own workstation
driving `scripts/deploy.sh` (Milestone 10), or the hypervisor's first-boot hook chaining
straight into Terraform and Packer itself. Chose the operator route. The hook's only job
is minting the two tokens this project already splits by tool (one for Terraform, one for
Packer, so either can be revoked alone) and writing them to a root-only-readable file;
whatever runs `deploy.sh` retrieves them over the same SSH connection the Milestone 8
task 4 host firewall rule already allow-lists to one address, and takes it from there.
Rejected: the hypervisor's own first-boot hook running the whole build — removes the wait
for a human or a runner to fetch the tokens, but it means the orchestration logic lives
and executes somewhere with no git history of its own, on a machine this project
otherwise treats as a minimal appliance rather than a place to install general-purpose
tooling.
Rejected: the installer's own post-installation webhook feature as the token-delivery
route — it is real, but built for install-status reporting, not for carrying secrets, and
using it here would mean standing up a receiver just for a one-time run.
Note: the billing check above corrects [The proof run is rented hourly bare metal, not
purchased hardware](#the-proof-run-is-rented-hourly-bare-metal-not-purchased-hardware),
which named Hetzner and Scaleway as interchangeable without checking either provider's
actual terms — see the note added there.

### Zero-touch deployment supersedes the manual OPNsense bootstrap and hardens the manual/code boundary finding

Why: Milestones 9 and 10 exist to remove every step Milestone 8's runbook currently asks
a person to do by hand before a proof run runs up a bill. The OPNsense bootstrap decision
rejected exactly the mechanism — a seeded config.xml — that the SPIKE above just confirmed
is real, current, and how OPNsense itself recommends scripted deployment. Code written
against the old boundary before this reversal is recorded would contradict the plan it
claims to implement, which is what `AGENTS.md` requires this entry to prevent.
How: [The OPNsense bootstrap is manual, and the boundary is stated in the runbook]
(#the-opnsense-bootstrap-is-manual-and-the-boundary-is-stated-in-the-runbook) now carries
a `Replaced by:` line pointing here. [The manual/code boundary is interface assignment
and addressing, not VLANs](#the-manualcode-boundary-is-interface-assignment-and-addressing-not-vlans)
is amended, not retracted — its finding that no provider resource assigns or addresses an
interface still holds, and is the reason the assignment now has to be baked into a
template rather than typed once; only who performs that step changes. Milestone 9 runs
before Milestone 8 despite its higher number, because the point is a zero-touch build to
run the proof on, not a retrofit after it — Milestone 8's own heading says so, and every
task in it that assumed a manual OPNsense bootstrap (its tasks 1, 4-7) gets revised once
Milestone 10 exists to replace them, not before.
Secrets this milestone adds, all generated rather than typed, all living only in the
gitignored `.env` alongside the guest passwords the earlier secrets decision already put
there: the OPNsense root password, its API key and secret (only the secret's SHA-512-crypt
hash reaches the committed `config.xml` template), and the Proxmox host's own root
password and the two API tokens its first-boot hook mints. None of these are a new
category of secret under that decision — they extend the same file.
Rejected: leaving the two superseded decisions unmarked and adding new ones alongside
them — `AGENTS.md` requires a rejected option to stay rejected until its entry is
replaced, and the manual bootstrap decision explicitly rejected the mechanism this
milestone now adopts. Two decisions in the same file giving opposite answers to the same
question is worse than either answer alone.

### SPIKE: the host's network exists in stages — provider DHCP, then a build network, then VLAN 10

Why: Milestone 10 moves the whole build onto the Proxmox host (decision 38), so the host
needs a real, working network at every point it makes a connection, in the order it
connects: a bare uplink at install time, a network Packer's builds can actually reach
before OPNsense exists to route anything, and finally its own tagged address on VLAN 10
once `vmbr1` exists. As written, none of the three holds. `proxmox/answer.toml`'s
`[network]` section named a static address (`10.10.10.2/24`) with gateway `10.10.10.1` —
a VM that does not exist at install time. Both Windows Packer sources sit their build VM
on `vmbr0` under a comment calling it "the trunk bridge", while `terraform/variables.tf`
already treats `vmbr0` as WAN. And OPNsense's own build source disables the guest agent
and sets no `ssh_host`, so Packer has no way to address that build VM at all.
How: researched live (2026-09-13), each finding checked against a current source rather
than assumed:
- Proxmox's answer-file schema documents exactly two `[network]` sources:
  `from-dhcp` (every other network key forbidden) and `from-answer` (static, needs
  `cidr`/`gateway`/`dns`) — confirmed against the wiki page directly, the same source
  Milestone 9 task 9 already pulled the rest of the schema from. Rented bare-metal
  providers configure the primary NIC by DHCP automatically at install (confirmed for
  Scaleway's own Elastic Metal docs specifically — a public IPv4 is assigned and the
  primary interface configures itself via DHCP; only a manually *added* interface needs
  a `dhclient` nudge). `answer.toml` therefore moves to `source = "from-dhcp"` with no
  `cidr`/`gateway` at all.
- Proxmox VE's networking stack (`ifupdown2`, default since 7.0) creates a VLAN-aware
  bridge with two lines on the bridge itself — `bridge-vlan-aware yes` and
  `bridge-vids 2-4094` — and a host-side tagged address as a `<bridge>.<vlan>`
  sub-interface (`vmbr1.10`), applied live with `ifreload -a`, no reboot needed —
  confirmed against the current Network Configuration wiki page and cross-checked
  against independent current guides using the identical pattern.
- `/etc/pve/pve-root-ca.pem` is the real file a local API client has to trust: copy it
  into `/usr/local/share/ca-certificates/` (renamed `.crt`) and run
  `update-ca-certificates` — confirmed against the Certificate Management wiki page.
  Whether the default `pve-ssl.pem`'s SAN list actually covers `localhost` or the
  configured FQDN closely enough for that trust to be sufficient is *not* confirmed by
  that page or anything else checked — left as a residual unknown below, not assumed.
- An empty OPNsense `<filter>` blocks inbound access to the firewall's own management
  service on any interface that is not flagged `<lan>` — the automatic anti-lockout rule
  only ever attaches to whichever interface holds that specific role, and
  `packer/files/config.xml` gives none of `opt1`/`opt2`/`opt3` that role (confirmed
  against OPNsense/pfSense anti-lockout documentation and a live OPNsense issue —
  opnsense/core#7372 — describing exactly this interface-scoping behavior). So
  `10.10.10.2` reaching OPNsense's own API on `opt1` (`10.10.10.1:443`) needs an
  explicit rule exactly like every other cross-VLAN access in this project, not
  something the empty ruleset already grants because the traffic is "local." This is a
  real gap in `opnsense/firewall.tf` that predates this milestone, not new scope
  invented for it — task 6 closes it.
Confirmed: every bullet above against a current, named source, the same discipline every
prior SPIKE in this project has used — nothing here is carried over from the older,
now-wrong `answer.toml`/Packer-source assumptions without being re-checked.

The decision:
1. **Install-time network** — `proxmox/answer.toml` moves to `source = "from-dhcp"`: the
   provider's uplink, not a lab address. This removes the nonexistent-gateway bug
   outright rather than patching its value.
2. **`vmbr1` and the host's own `10.10.10.2`** are created by the host-side runner's
   first stage over SSH (task 8), not `proxmox/first-boot-hook.sh`. The hook stays a
   single-purpose appliance script minting two API tokens and nothing else — growing it
   into general host network configuration repeats exactly the reasoning decision 34
   already rejected once for "the hook running the whole build." Doing it from the
   runner instead also means the same script works whether Proxmox came from the
   prepared ISO or from Scaleway's own Proxmox VE catalog image for the Beryllium range
   (real and current, confirmed while researching this) — neither path depends on the
   first-boot hook running at all.
3. **Where build VMs attach** — a third bridge, `vmbr2`, internal-only, VLAN-unaware,
   carrying one flat, disposable subnet (`10.10.99.0/24`) that exists only because a
   Packer build needs somewhere to put a VM before OPNsense exists to route anything.
   The runner starts a small `dnsmasq` bound to it before calling `packer build`. This
   is deliberately not VLAN 10: `docs/network-design.md` states plainly that Management
   "gets no DHCP scope of any kind," and routing build traffic onto the same bridge as
   the host's own permanent address would either contradict that sentence or carve an
   exception into it for a need that disappears the moment the templates exist.
4. **How each build VM is addressed on it** — the two Windows builds keep
   `qemu_agent = true` and, once task 4 fixes the ordering bug that installs the agent
   after WinRM was supposed to already be reachable, discover their real address through
   the agent the way they always should have; `vmbr2`'s DHCP lease is incidental, any
   address works. OPNsense has no agent, so its build VM's WAN NIC (`vtnet0`) gets a
   fixed MAC in `packer/opnsense.pkr.hcl` and a matching static reservation in the
   runner's `dnsmasq` config; the source block's `ssh_host` is set to that reserved
   address. Nothing about `config.xml`'s actual WAN setting changes to make this work —
   WAN is `dhcp` in both the build network and production, so build-time and shipped
   behavior never diverge.
Rejected: attaching build VMs to VLAN 10 directly — reuses an existing bridge instead of
adding one, but contradicts the standing "Management has no DHCP" sentence in
`docs/network-design.md` and leaves a build-only DHCP server running on the same
broadcast domain as the host's own permanent address indefinitely, for a need that ends
the moment the templates exist.
Rejected: growing `proxmox/first-boot-hook.sh` to also build `vmbr1`/`vmbr2` — keeps
everything in one appliance script, but repeats the reasoning decision 34 already
rejected once, and stops working the moment Proxmox comes from the provider's own
catalog image instead of the prepared ISO.
Rejected: a raw FAT32 disk image in place of `vmbr2` for OPNsense's build-time
reachability — solves a different, already-tracked unknown (whether the config-importer
reads an ISO9660 volume at all) and has nothing to do with SSH reachability during the
build; not applicable here.
Residual unknown, left for the Milestone 8 proof run: whether Proxmox's default
self-signed certificate actually carries `localhost` or the node's configured FQDN in
its SAN closely enough for `insecure_skip_tls_verify = false` to validate once
`pve-root-ca.pem` is trusted. Task 8 points `PROXMOX_VE_ENDPOINT`/`PKR_VAR_proxmox_url`
at the node's own configured name (`pve.silab.internal`, with a `/etc/hosts` entry
since no DNS exists yet) rather than `localhost`, on the reasoning that this is the name
Proxmox's own cert-generation step signs for — inference from how Proxmox is documented
to behave at install time, not a confirmed fact about `pve-ssl.pem`'s actual SAN list.

### SPIKE: Terraform starts each Bootstrap script and lets go; a bash poll loop on the host watches phase.json

Why: the Terraform handoff runs each Bootstrap script synchronously over WinRM today.
DC01's first phase removes and re-adds its only address — a brief local interruption
that can drop the very WinRM session `remote-exec` is blocked on — and its promotion
phase reboots the guest inside that same blocking command. Either one kills the
session mid-command, which fails the provisioner, taints the resource, and makes the
next `terraform apply` try to destroy and recreate a half-built domain controller.
Something then has to know when every phase on every guest has finished and run
`Test-SILab.ps1`, from a Linux host with no PowerShell of its own.
How: researched live (2026-09-13) and read directly against this project's own code
where the answer already existed rather than designed from scratch:
- Terraform's WinRM/SSH provisioners have no built-in way to survive a connection
  dropped mid-command by a guest reboot — a known, long-standing, unresolved class of
  issue (checked against multiple current `hashicorp/terraform` issue threads
  describing exactly this DC01-shaped scenario: run a command, reboot, run more
  commands, all in one provisioner). The mitigation the community actually uses is
  always the same shape: separate "start something that survives its own reboot" from
  "wait for it" — never one blocking call spanning the reboot.
- Windows already gives this project the "start" half for free: `Start-Process
  -WindowStyle Hidden` launches a detached child process and returns immediately, so
  one WinRM command that calls `Start-Process powershell.exe -ArgumentList
  '...Bootstrap-DC01.ps1 ...'` completes — and lets `remote-exec` return successfully —
  before the child ever reaches its first reboot. This is ordinary, version-independent
  Windows process behavior, not something to verify against a pin.
- The completion signal already exists and needs no new file: `Set-SILabPhase`
  (Milestone 6, `powershell/SILab.psm1`) already writes
  `C:\ProgramData\SILab\phase.json` with the current phase number, before any call that
  reboots — built for the resume mechanism, not for this milestone, but it is exactly
  the signal this task went looking for. Read directly, not assumed: DC01's terminal
  phase is 5 (`Bootstrap-DC01.ps1`).
- `Register-SILabResumeTask` (same module) registers its resume trigger with **no
  credential in its argument list** — `-File $PSCommandPath`, nothing else — because
  every phase after the one that reboots needs no credential at all
  (credential-ordering decision). Read directly from `powershell/SILab.psm1` and
  `Bootstrap-DC01.ps1`, not assumed. So the specific risk this task's own "reject any
  [mechanism] that writes them to disk" warning is aimed at — a scheduled task created
  with sensitive arguments baked into its own on-disk definition — was never how this
  project resumes a script; it only becomes a real risk if the *initial*, credentialed
  launch used a scheduled task instead of `Start-Process`, which is exactly what gets
  rejected below.
- `terraform_data` (built into Terraform since 1.4, well under the pinned 1.16.1) is
  the current, official replacement for `null_resource` and supports its own
  `connection`/`provisioner` blocks — confirmed against current Terraform documentation
  — so a WinRM check *could* be wired into `terraform/` itself. But reusing it for the
  actual polling loop still means invoking `terraform apply` once per poll attempt, a
  full provider-init/state-lock/plan/apply cycle to run what is really one remote
  command. `pywinrm` was the other named candidate; nothing in its own GitHub
  repository (README, releases) gave a confirmable maintenance signal as of this check.
- Decision: neither. The host-side runner (task 8) is bash, already on the one machine
  with a direct route to every guest, and needs exactly one thing from WinRM twice over:
  run a command, get its output — to poll `phase.json` and to run `Test-SILab.ps1`. That
  is a single HTTP request with NTLM auth, not a session Terraform or a Python library
  needs to manage. `curl --ntlm` (present on any Debian host already, nothing new to
  pin) issues that request directly, using the same `use_ntlm = true` /
  unencrypted-transport choice `terraform/vm-dc01.tf`'s own `connection` block already
  made and documented for port 5985.
The decision:
1. Every guest's `remote-exec` provisioner changes to launch its Bootstrap script via
   `Start-SILabDetached` (`powershell/SILab.psm1`) and returns — Terraform's job ends
   there, exactly as task 7 puts it: the guest already drives itself across reboots by
   design, Terraform only needs to start it and get out of the way. See the correction
   below on why this is a one-shot scheduled task, not `Start-Process`.
2. The host-side runner polls each guest's `phase.json` over WinRM (`curl --ntlm`) in a
   bash loop with a sleep between attempts. A failed attempt — the guest is mid-reboot
   and unreachable — is just a failed `curl` call retried on the next iteration, never a
   Terraform provisioner failure and never a tainted resource.
3. Once every guest's phase file reports its terminal phase, the runner copies and runs
   `Test-SILab.ps1` on DC01 the same way; its exit code becomes the whole deployment's
   exit code (task 10).
Rejected: a `terraform_data` resource reusing Terraform's own WinRM client for the poll
loop — real and supported, but turns "wait for completion" into a shell loop invoking
`terraform apply` repeatedly, paying a full provider/state cycle for one remote command,
and splits the polling logic across two languages the runner has to drive either way.
Rejected: `pywinrm` — works, but adds a pip dependency and a Python runtime to a host
this project otherwise provisions with exactly two pinned, checksum-verified static
binaries and nothing else; its maintenance status could not be confirmed live, which
disqualifies it on its own given every other tool in this repo is checked against its
current, live state before being trusted.
Residual unknown: whether `curl --ntlm` against WinRM's raw endpoint needs anything
beyond `-u user:pass` and the right `Content-Type`/SOAP body to get a usable reply from
a Windows Server 2025 WinRM listener is unverified until the proof run. The mechanism —
NTLM auth over HTTP on port 5985 — is identical to what `terraform/vm-dc01.tf`'s own
connection block already relies on; only the client issuing the request differs.

Correction, found while implementing task 7 (2026-09-13): `Start-Process` does not
work, and this SPIKE was wrong to pick it. A real, open `PowerShell/PowerShell#16001`
issue — "Remote sessions terminate Start-Process-launched processes on exit" — confirms
that a process started directly inside a WinRM/PSRemoting shell is a member of that
shell's Windows job object, and Windows job objects kill every member the instant the
job's last handle closes. Terraform's `remote-exec` closes the WinRM shell right after
the command it ran returns — which, for a `Start-Process` call that succeeds and
returns immediately, is essentially the same moment the detached child was created. The
mechanism this SPIKE chose to make the provisioner "return at once" is the exact
mechanism that gets the detached child killed at that same instant, not a separate
concern from it.
The actual fix is the one this SPIKE rejected: a scheduled task. Task Scheduler spawns
its own process tree outside any caller's job object entirely, which is *why* it
escapes this problem where `Start-Process` cannot — confirmed independently twice, not
inferred once: Packer's own `windows-restart`/elevated-command provisioner uses a
scheduled task (`elevated-template.ps1`) for exactly this reason, and Ansible's own
Windows documentation names a scheduled task as the standard way to run something over
WinRM that needs to outlive the calling session. This SPIKE's original objection —
"a scheduled task persists its argument string, credential included, to disk" — still
holds, and is not avoidable: no channel from a WinRM-connected process to a
Task-Scheduler-spawned one avoids disk entirely, since they share no memory and Task
Scheduler has no "pass this argument once, store nothing" mode. `Start-SILabDetached`
minimizes rather than eliminates the exposure: it registers the task, starts it,
confirms (by polling `State -eq 'Running'`) that the real process has actually been
created, and deletes the task definition immediately afterward — deleting a task does
not stop an instance already running, since that instance is by then a child of the
Task Scheduler service, not of the definition being deleted. The credential sits in a
file on disk for at most a couple of hundred milliseconds, never across a reboot and
never as standing state, which is the narrowest exception to "no credential is ever
written to the guest's disk" this project has taken — a real exception, not a loophole
argued around it, since a task definition is unambiguously a file. `on_failure =
"continue"` on the provisioner was considered as an alternative fix and rejected: it
stops a genuinely dead reboot-interrupted connection from tainting the resource, but
the provisioner still blocks for up to its own connection `timeout` (10 minutes) before
giving up, which fails task 7's actual Accept criterion — "no provisioner waits" —
even though it would have solved the tainting half well enough on its own.

### The Packer/Terraform build runs on the Proxmox host itself; deploy.sh is a thin SSH wrapper around it

Why: decision 34 put `scripts/deploy.sh` on the operator's workstation, driving Packer
and Terraform against the Proxmox API remotely, and had the first-boot hook's tokens
travel to the operator over SSH for exactly that reason. Both halves turn out to be
wrong once OPNsense is actually part of the topology: Packer's WinRM communicator and
Terraform's WinRM provisioner both connect directly, with no bastion/jump-host option —
checked against both tools' current connection documentation, not assumed from how
other tools behave — and once the lab's guests sit behind OPNsense on
`10.10.20.0/24`/`10.10.30.0/24`, only the Proxmox host has a route to them. An
operator's laptop reaching in over the internet has none, short of standing up a VPN or
port-forward this project has no other reason to build.
How:
1. `scripts/deploy.sh`, run on the operator's own machine with the rented server's
   address as its argument, copies the repository plus `.env` to the host over SSH and
   invokes the host-side runner (task 8) there. It never calls `packer` or `terraform`
   itself, and needs nothing installed beyond an SSH client.
2. The two Proxmox API tokens no longer need to leave the host at all: the runner reads
   `/root/proxmox-api-tokens.txt` directly — it already runs as root, on the box the
   file is on — merges its two lines into the host's own `.env`, and deletes the token
   file. `scripts/deploy.sh` never touches them; the "travel to the operator over SSH"
   half of decision 34 is what this entry actually supersedes.
3. Renting and releasing the server stay exactly as manual as Milestone 8 already
   planned — nothing here adds a provider API key to `.env`, and nothing automates
   either end of the machine's lifecycle. `deploy.sh` starts once the host answers SSH
   and ends by printing the reminder to release it (task 10).
4. Every installation ISO downloads on the host itself, never across the operator's own
   connection — task 5 — from URLs and checksums in a non-secret var file, never `.env`.
Rejected: keeping orchestration on the operator's workstation and adding a WireGuard
tunnel or SSH port-forwards into the lab's VLANs — solves reachability, but adds a
second piece of standing infrastructure (a tunnel, its own keys, its own firewall rule)
for a build this project runs once and tears down, and removes none of the complexity
this milestone exists to remove.
Rejected: driving the build through the Proxmox API's own remote surface (`pvesh`/the
REST API) as a jump point from the operator's machine — the API can create and manage
VMs remotely, but Packer's and Terraform's own communicators still need a direct
network path to the guest for WinRM, which the API does not provide.
Rejected: automating the rental and release of the server through the hosting
provider's own API — renting and releasing were never the slow or error-prone half of
this milestone, and automating them would put a provider API key somewhere this
project has to keep it, which is exactly the credential the secrets decision keeps out
of `.env`. Both stay a human clicking a button in the provider's console.
Rejected: uploading ISOs from the operator's workstation — the default implication of
every earlier plan; explicitly rejected now that the build runs on the host anyway,
since datacenter-to-datacenter bandwidth for four multi-gigabyte images strictly beats
routing them through a home connection while the server bills by the hour.
See also [SPIKE: the host's network exists in stages](#spike-the-hosts-network-exists-in-stages--provider-dhcp-then-a-build-network-then-vlan-10)
and [SPIKE: Terraform starts each Bootstrap script and lets go](#spike-terraform-starts-each-bootstrap-script-and-lets-go-a-bash-poll-loop-on-the-host-watches-phasejson),
the two SPIKEs this entry closes out alongside its own finding.
