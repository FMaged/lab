# docs/

The design the rest of the repository implements. Nothing here has been executed —
see [Execution status](../README.md#execution-status).

| Document | What it holds |
| --- | --- |
| [walkthrough.md](walkthrough.md) | One machine traced end to end, from installation media to an applied Group Policy. The best starting point. |
| [network-design.md](network-design.md) | VLANs, subnets, the static address table, DHCP scopes and reservations, DNS, and the firewall policy every rule implements. |
| [network-diagram.md](network-diagram.md) | The same network as a diagram, with addressing. |
| [ad-design.md](ad-design.md) | Forest and domain, functional level, the OU tree and why it has that shape, the two groups, and the three baseline GPOs. |
| [conventions.md](conventions.md) | Hostnames, VM IDs, MAC addresses, template and ISO names, Terraform naming, tags, formatting and pinning rules, and the branch and commit scheme. |
| [hardware.md](hardware.md) | What a Proxmox host would need, and the two viable NIC layouts. |
| [runbook.md](runbook.md) | Bare metal to a working domain in order, section by section. Sections 1 and 6 wait on a host. |

`network-design.md` and `ad-design.md` are specifications, not descriptions: the
Terraform, OPNsense and PowerShell layers implement them, and a value that
contradicts either is a bug in the code rather than a variation. Start at the
top-level [README.md](../README.md) for the full reading order.
