# Conventions

## VM and hostname scheme

`<ROLE><NN>` — a short role code, two-digit sequence number, no separator. Already
fixed by the topology decision in `PLAN.md`:

| Hostname | Role |
| --- | --- |
| DC01 | domain controller |
| SRV01 | member server |
| CL01 | client (Windows 11) |

OPNsense keeps its own name (`opnsense`, lowercase) — it is not a Windows guest and
never joins the domain, so applying the Windows scheme to it would be misleading.
A second host of the same role, if one is ever added, is `SRV02` — never a
descriptive suffix like `srv-web`, since the number is what makes scripts able to
iterate over a role.

## Terraform naming

- Resource label matches the hostname, lowercased: `proxmox_virtual_environment_vm.dc01`.
- Variables are `snake_case`, prefixed by what they configure:
  `network_vlan_servers`, `network_vlan_clients`, `proxmox_node_name`.
- One file per host (`vm-dc01.tf`, `vm-srv01.tf`, …) plus `network.tf`,
  `providers.tf`, `variables.tf` — see the `terraform-proxmox` skill for the full
  layout rule.

## VM tags (Proxmox)

Every VM gets both of:

- `lab` — marks it as part of this project, distinct from anything on the existing
  homelab host.
- One role tag: `role-dc`, `role-member-server`, `role-client`, `role-firewall`.

Tags are how a reviewer (or a script) can tell at a glance what a VM is for without
opening its config — Proxmox shows them directly in the VM list.

## Formatting and pinning (CI-enforced)

- `terraform fmt` and `packer fmt` clean at all times, in `terraform/`, `opnsense/`
  and `packer/` — CI runs both with `-check` and fails the build on drift. Run the
  formatter before committing rather than finding out from a red build.
- Every provider and plugin is pinned to an exact version — `version = "0.112.0"`,
  never `version = "~> 0.112"`. Nothing here can be applied to catch a breaking
  change early, so an unpinned constraint is a build that can fail on a Tuesday with
  no code change behind it. See `terraform/versions.tf`, `opnsense/versions.tf` and
  `packer/plugins.pkr.hcl`.
- Bumping a pinned version is a deliberate, single-purpose commit — read the
  changelog first, especially for the OPNsense provider (pre-1.0, no stability
  guarantee per the decision in `PLAN.md`).

## Branch and commit conventions

Follow the global `git-conventions` skill as written — Conventional Commits, single
line, no body or footer. This is a solo project with no ticket tracker, so the
`no-ref` branch form is the default: `feature/no-ref/<description>`,
`docs/no-ref/<description>`. `main` is exempt and is where small, low-risk commits
(docs, config) land directly; a branch is for anything large enough to want a
reviewable diff before it merges.
