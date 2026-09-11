# SI Portfolio Lab

## Goal

A small company network built entirely as code — Proxmox host, Windows Server 2025
image, VMs, Active Directory, and a routed multi-VLAN network — that can be torn
down and rebuilt from the repo. It exists to support a career switch from
Anwendungsentwicklung to Systemintegration.

The reader is a hiring manager, not a customer. Success is a reviewer understanding
what was built and why in five minutes, and being able to see that it actually runs.

## Not in scope

- Not a product. No users, no income, no support.
- No high availability, no Proxmox clustering, no failover.
- No cloud and no hybrid identity (no Entra ID / Azure AD Connect).
- No monitoring, logging or backup stack in the first pass.
- No sysprep / image generalization.
- Does not touch the existing homelab host. Separate hardware only.

## Stack

| Part | Choice |
| --- | --- |
| Hypervisor | Proxmox VE 9.2 on new, separate hardware |
| Image build | Packer — Windows Server 2025 base image with VirtIO drivers and WinRM |
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
