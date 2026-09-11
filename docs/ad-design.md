# Active Directory design

## Forest and domain

| Item | Value |
| --- | --- |
| Forest root domain | `ad.silab.internal` (see the PLAN.md decision on the `.internal` TLD) |
| NetBIOS name | `SILAB` |
| Forest / domain functional level | Windows Server 2025 |
| Site name | `SILAB-Lab` (the default site, renamed — one site, no replication topology to design) |
| Domain controller | DC01 |

Functional level is 2025 because there is no legacy DC to stay compatible with —
raising it later would need a second decision and a forest-wide check, so it starts
at the ceiling.

## OU structure

```
ad.silab.internal
└── SILAB
    ├── Computers
    │   ├── Servers        (SRV01)
    │   └── Workstations   (CL01)
    ├── Users
    ├── Groups
    └── Service Accounts
```

Built-in `Domain Controllers` keeps DC01 — it is never moved, since moving a DC out
of its default OU breaks the GPOs Microsoft links there.

A single top-level `SILAB` OU (rather than linking everything at the domain root)
exists so that domain-root GPO links stay reserved for the one policy that
genuinely belongs there (the password/lockout baseline, below) and every other
policy is delegated and scoped underneath it. `Computers` splits into `Servers` and
`Workstations` because they get different baseline GPOs — the split is what makes
that link scope possible, not organizational taste. `Service Accounts` is separate
from `Users` so a future GPO or delegation aimed at one never accidentally reaches
the other.

## Groups

| Group | Type | Purpose |
| --- | --- | --- |
| `SILAB-Admins` | Security, Global | Domain administration — delegated rights over the `SILAB` OU tree |
| `SILAB-Helpdesk` | Security, Global | Password resets and workstation support, no server access |

Two groups, not a full RBAC matrix — this lab has one operator. The pair exists to
show delegation is scoped by group membership rather than everyone using the
built-in Domain Admins account for daily work.

## Baseline GPOs

| GPO | Linked to | Enforces |
| --- | --- | --- |
| Domain Password & Lockout Policy | domain root | Min. password length 12, complexity on, account lockout after 5 attempts |
| Workstation Baseline | `Computers/Workstations` | Logon legal notice ("Authorized use only"), desktop wallpaper, Windows Defender real-time protection on |
| Server Baseline | `Computers/Servers` | Windows Firewall (domain profile) on, SMBv1 disabled, enhanced audit policy logging on |

The Workstation Baseline's logon notice is the policy Milestone 6 checks for — it is
the one thing on CL01 that is trivially visible (a screenshot of the logon screen)
as proof a GPO actually applied, not just linked.

## Constraints this places on later milestones

- Milestone 5's PowerShell must create the OU tree and the two groups before
  anything is moved into them, and must place SRV01's computer object in
  `Computers/Servers` — Terraform only creates the VM, it does not know about OUs.
- Milestone 6 must show CL01's computer object landing in `Computers/Workstations`
  and the logon banner appearing after a `gpupdate` / reboot.
