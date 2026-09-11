# Runbook: bare metal to a working domain

Ordered, end to end. Each section is a placeholder until its milestone in
`TASKS.md` lands — filled in with the actual commands and any gotchas hit while
doing it, not written speculatively ahead of the work.

## 1. Proxmox host install

*(Milestone 2 — not started. Will cover: ISO install, network/VLAN bridge setup
matching `docs/hardware.md`, and confirming the host is reachable at 10.10.10.2.)*

## 2. Packer image build

*(Milestone 3 — not started. Will cover: running the Packer build, where the
resulting template lands in Proxmox, and how to rebuild it.)*

## 3. OPNsense setup

*(Milestone 4 — not started. Will cover: applying the VLAN/interface/DHCP/firewall
config decided by the Milestone 1 SPIKE, and verifying each VLAN routes.)*

## 4. DC01 — domain controller

*(Milestone 5 — not started. Will cover: `terraform apply` for DC01, then running
the promotion PowerShell against `docs/ad-design.md`, and verifying AD DS/DNS come
up.)*

## 5. SRV01 and CL01 — join the domain

*(Milestone 6 — not started. Will cover: `terraform apply` for both, the domain-join
PowerShell, and confirming the Workstation Baseline GPO's logon banner appears on
CL01.)*

## 6. Full rebuild, start to finish

*(Milestone 7 — not started. Will cover: tearing everything down and replaying
sections 1–5 in order from a clean host, as the final proof the repo is complete.)*
