---
name: terraform-opnsense
description: Conventions for this repo's OPNsense configuration via the browningluke/opnsense Terraform provider — layout under opnsense/, VLAN interfaces, Kea DHCP, firewall filter rules and NAT as Terraform resources, and the pre-1.0 provider-stability risk. Use when writing or changing anything under opnsense/, when the user mentions OPNsense, the browningluke provider, firewall rules, VLAN interfaces or DHCP config as Terraform resources. Not for VM provisioning against Proxmox (see terraform-proxmox) and not for the base image (see packer-windows).
---

# OPNsense-via-Terraform conventions for the SI lab

Configures the router and firewall as Terraform resources against OPNsense's REST
API, through the community `browningluke/opnsense` provider — so the firewall is
part of the same `terraform apply` as every VM, not a second automation mechanism.

## Layout

Code lives in `opnsense/`, as its own Terraform root (separate state from
`terraform/`, since OPNsense and the Proxmox VMs have independent lifecycles — the
firewall config does not need to change every time a VM does, and vice versa). One
file per concern: `provider.tf`, `interfaces.tf`, `dhcp.tf`, `firewall.tf`.

Addresses, VLAN IDs and DHCP pools come from `docs/network-design.md` — never
invent one here; if the design is wrong, change the design first.

## Constraints from PLAN.md

- **Pin the provider to an exact version.** It is pre-1.0 and makes no stability
  guarantee — an unpinned `~>` constraint can pull a breaking change on a routine
  `terraform init`. Bump deliberately, re-read the changelog, and re-`plan` before
  `apply`.
- **API key/secret auth**, from `OPNSENSE_API_KEY` / `OPNSENSE_API_SECRET`
  environment variables — never written to a file, per the secrets decision in
  `PLAN.md`.
- **This root configures a firewall that already exists.** Installing OPNsense,
  assigning its interfaces, addressing them and enabling the API are a documented manual
  bootstrap — see the bootstrap decision in `PLAN.md` and section 3a of
  `docs/runbook.md`. Everything past the API key is code. If a setting turns out not to
  be exposed as a resource, it moves into the runbook's manual half with a note, never
  into a shell script wrapped in a provisioner.
- **Rules are least privilege with a reason on each one.** `docs/network-design.md`
  carries the policy table; this root implements it. A rule that is not in that table
  does not belong here, and a broad allow between VLANs contradicts a decision in
  `PLAN.md`.
- **DHCP is Kea, and it serves two VLANs for two different reasons.** The Clients VLAN
  has a real pool, because CL01 is an ordinary client. The Servers VLAN has a
  reservation-only scope with no pool at all — it exists solely so a freshly cloned DC01
  and SRV01 come up reachable for Terraform's WinRM handoff, after which PowerShell makes
  the address static. See the bootstrap addressing decision in `PLAN.md`. The Management
  VLAN still gets nothing. A pool on the Servers VLAN is a bug, not an omission.
- **Reservations key on MACs pinned in `terraform/`.** Address and MAC both come from the
  design documents — addresses from `docs/network-design.md`, MACs from
  `docs/conventions.md`. Changing either on one side alone silently breaks the bootstrap
  in a way no validator will catch.

- **This configuration cannot be applied.** There is no OPNsense instance to reach,
  so `plan` and `apply` are unavailable during development. `terraform validate` with
  `-backend=false` in CI is the only feedback. Validate passes on resource arguments
  the API would still reject, so read the provider docs for each resource rather than
  trusting a green build.

## Conventions

- Every VLAN interface resource's `vlan_id` and parent interface must match
  `docs/network-design.md` exactly — this file has no authority to redefine the
  network, only to implement it.
- Firewall filter rules get a `description` that says what the rule is for, not just
  the ports — an unlabeled allow rule is a liability in a security-adjacent project.
- Read the plan before every apply here as carefully as in `terraform/` — a firewall
  rule that gets destroyed and recreated can cut Terraform's own access to apply the
  rest of the change.

## Gotchas

<!-- Empty until this configuration exists (Milestone 4). Anything that costs more
than an hour to work out goes here, not in a commit message. -->
