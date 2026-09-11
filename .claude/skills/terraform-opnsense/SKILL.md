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
- **DHCP is Kea, and only serves the Clients VLAN** (see `docs/network-design.md`).
  Management and Servers VLANs get no DHCP resource — their hosts are static and
  already listed in the address table.

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
