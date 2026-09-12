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
