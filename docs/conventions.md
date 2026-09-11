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

## Branch and commit conventions

Follow the global `git-conventions` skill as written — Conventional Commits, single
line, no body or footer. This is a solo project with no ticket tracker, so the
`no-ref` branch form is the default: `feature/no-ref/<description>`,
`docs/no-ref/<description>`. `main` is exempt and is where small, low-risk commits
(docs, config) land directly; a branch is for anything large enough to want a
reviewable diff before it merges.
