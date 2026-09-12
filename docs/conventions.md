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

## Packer templates and ISOs

| Template name | Guest | Built from |
| --- | --- | --- |
| `tpl-winsrv2025-de-v1` | DC01, SRV01 | German Windows Server 2025, Desktop Experience |
| `tpl-win11-de-v1` | CL01 | German Windows 11 Pro |
| `tpl-opnsense-v1` | OPNsense | Official OPNsense installer ISO, config baked in via the live-image importer (see the zero-touch decision in `PLAN.md`) |

`tpl-` marks it as a Packer artifact, never a running guest, in the Proxmox VM
list. The trailing `-v<N>` is mandatory, not decoration — per the packer-windows
skill, a changed image is a new template, never an edit of the old one, and the
version number is what makes that rule visible without opening the build files.
Bumping it is a Terraform change too, since `terraform/` clones by template name;
the old template stays until nothing references it, then gets deleted.

Template VMIDs live in a reserved `9000`–`9099` range, kept clear of every guest
VMID so a future guest can never collide with a template by accident.

| Template | VMID |
| --- | --- |
| `tpl-winsrv2025-de-v1` | 9000 |
| `tpl-win11-de-v1` | 9001 |
| `tpl-opnsense-v1` | 9002 |

ISOs live on the `local` datastore as `local:iso/<file>`:

| File | Contents |
| --- | --- |
| `win-server-2025-de.iso` | German Windows Server 2025 installation media |
| `win-11-pro-de.iso` | German Windows 11 Pro installation media |
| `virtio-win-<version>.iso` | VirtIO drivers, version pinned to match `packer/variables.pkr.hcl` |
| `OPNsense-26.7-dvd-amd64.iso` | Official OPNsense installer media (decompressed from the `.iso.bz2` download — Proxmox needs the raw ISO) |

No "latest" symlink or unversioned VirtIO filename — the exact version in the
filename is what lets a rebuild months later use precisely what the original build
used, per the same pinning discipline as every other tool in this repo.

## New top-level directories (zero-touch deployment)

| Directory | Holds |
| --- | --- |
| `proxmox/` | The `answer.toml` template and the ISO-preparation step that make the rented host install itself — see the zero-touch decision in `PLAN.md`. Runs once, before any Terraform or Packer command. |
| `scripts/` | Operator tools that run against a real host or a real `.env` — `init-env.sh`, and Milestone 10's `deploy.sh`/`destroy.sh`. Kept apart from `.github/scripts/`, which holds CI-only checks that never touch a live host. |

## Guest VMIDs

`<VLAN ID>` × `10` + a per-VLAN sequence number, so the ID itself says which VLAN
the guest is on — clear of the `9000`–`9099` template range above.

| Host | VLAN | VMID |
| --- | --- | --- |
| OPNsense | 10 (Management) | 101 |
| DC01 | 20 (Servers) | 201 |
| SRV01 | 20 (Servers) | 202 |
| CL01 | 30 (Clients) | 301 |

OPNsense sits at Management even though it routes every VLAN — that's the one
address it has that isn't itself a gateway, per the static address table in
`docs/network-design.md`. A second host on Servers or Clients continues the same
VLAN's sequence (`203`, `302`, …), never restarting from a round number.

## Guest MAC addresses

`02:00:00:00:` + the VMID above as a 4-hex-digit, big-endian value split across
the last two octets — so the MAC can be derived from the VMID by eye, and the two
can never quietly disagree.

| Host | VMID | MAC |
| --- | --- | --- |
| OPNsense | 101 | `02:00:00:00:00:65` |
| DC01 | 201 | `02:00:00:00:00:C9` |
| SRV01 | 202 | `02:00:00:00:00:CA` |
| CL01 | 301 | `02:00:00:00:01:2D` |

`02` as the first octet is a locally administered, unicast address (bit 1 set,
bit 0 clear) — never a real vendor OUI, so it can never collide with actual
hardware. A DHCP reservation in `opnsense/dhcp.tf` keys on this MAC; Terraform
pins it explicitly on the matching guest's `network_device` rather than letting
Proxmox generate one, since a generated MAC changes on rebuild and silently
misses its reservation. See the bootstrap addressing decision in `PLAN.md`.

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

Follow the global `git-branch-conventions` and `git-commit-conventions` skills as
written — Conventional Commits, single line, no body or footer. This is a solo project
with no ticket tracker, so the
`no-ref` branch form is the default: `feature/no-ref/<description>`,
`docs/no-ref/<description>`.

One milestone is one branch, one task is one commit, one milestone is one PR. Branch
from `main` when the milestone's first task starts; each task in `TASKS.md` lands as a
single commit on that branch; the branch merges through one PR when every task in the
milestone is checked off. A task that cannot land in one commit is too big — split it in
`TASKS.md` first.

`main` stays exempt from the branch naming rules, and a one-off fix that belongs to no
milestone (a typo, a broken link) can still land on it directly. Milestones 1–3 predate
this and landed as direct commits — see the decision in `PLAN.md`.
