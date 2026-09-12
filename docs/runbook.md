# Runbook: bare metal to a working domain

Ordered, end to end. Each section is a placeholder until its milestone in
`TASKS.md` lands — filled in with the actual commands and any gotchas hit while
doing it, not written speculatively ahead of the work.

## 1. Proxmox host install

*(Milestone 8 — not started. Will cover: ISO install, network/VLAN bridge setup
matching `docs/hardware.md`, and confirming the host is reachable at 10.10.10.2.)*

## 2. Packer image build

**Never executed.** Every step below is validated (`packer fmt`/`init`/`validate`,
locally and in CI) but has never run against a real Proxmox host — there is no
host yet. See the execution status decision in PLAN.md; this note comes out the
moment a real build runs.

1. Upload the two installation ISOs and the VirtIO driver ISO to the Proxmox
   `local` datastore (or whatever `iso_datastore` is set to), named exactly as
   `docs/conventions.md` specifies — `win-server-2025-de.iso`,
   `win-11-pro-de.iso`, `virtio-win-<version>.iso`.
2. Copy `packer/example.pkrvars.hcl` to `packer/packer.auto.pkrvars.hcl`
   (gitignored) and fill in the real Proxmox URL, node, API token, ISO
   checksums and `local_admin_password` — or set the equivalent `PKR_VAR_*`
   environment variables instead. Never commit the filled-in file.
3. From `packer/`: `packer init .` (downloads the pinned Proxmox and
   Windows-Update plugins), then `packer build .`. Both sources build from one
   `packer build .` invocation, since they share the `windows-templates` build
   block — there is no way to build just one without commenting out the other's
   `source` entry in `build.pkr.hcl`.
4. Watch for the build reaching the WinRM communicator — this is the point the
   packer-windows skill calls "finished" for the unattended-install half. If it
   hangs before then, the most likely causes, in order: the VirtIO driver isn't
   at the drive letter the answer file expects (see the multi-letter hedge in
   both `autounattend-*.xml`), the image-index name doesn't match the real ISO
   (`docs/conventions.md`'s residual unknown, flagged since the Windows 11 SPIKE),
   or the bootstrap password in the answer file and the source block's
   `winrm_password` have drifted out of sync.
5. On success, confirm both templates exist in the Proxmox UI: `tpl-winsrv2025-de-v1`
   and `tpl-win11-de-v1`, VM IDs 9000 and 9001, tagged `lab` plus their role tag.
6. Re-running `packer build .` after a change always produces a *new* numbered
   template (`-v2`, `-v3`, …) per `docs/conventions.md` — it never overwrites
   `-v1` in place, even before Milestone 5 has anything cloning from it yet.

## 3. OPNsense setup

**Never executed.** Every step in 3a and 3b is written from the design docs and
validated where a validator exists; none of it has run against a real firewall.
See the execution status decision in PLAN.md.

### 3a. Manual bootstrap

The manual/code boundary is interface assignment and addressing, not VLANs — see
the decision in PLAN.md. Concretely, that means this half happens in two passes:
some of it before `terraform apply` creates the VLAN devices, the rest after.

**Before `terraform apply` for `terraform/vm-opnsense.tf`:**

1. `terraform apply` (root: `terraform/`) creates the VM. Attach the OPNsense
   installation ISO to the `local` datastore first, as `local:iso/opnsense.iso`
   — the VM won't boot without it.

**After the VM exists, before any Terraform touches `opnsense/`:**

2. Boot the VM and run the OPNsense installer from console (ZFS is fine for a
   lab; set a root password you'll actually remember, since it's what the web
   UI login uses too).
3. At the console menu, **Assign interfaces** (option 1): assign the WAN-bridge
   NIC as `wan` and note the trunk-bridge NIC's device name (e.g. `vtnet1`) —
   it stays unassigned for now; it's the VLAN devices Terraform creates from it
   in task 8 that get assigned, not the raw NIC itself.
4. Confirm WAN picked up a DHCP lease from the home router (console menu or
   Interfaces > WAN in the web UI) — no action needed if it did.
5. In the web UI: **System > Settings > Administration**, enable the API.
   **System > Access > Users**, create (or use an existing account) an API
   key/secret pair. This is the literal bootstrapping problem the decision in
   PLAN.md describes — nothing in `opnsense/` can run before this exists.

**After `terraform apply` for `opnsense/`'s VLAN devices exist (task 8):**

6. **Interfaces > Assignments**: assign each of the three new VLAN devices
   (`vtnet1.10`, `vtnet1.20`, `vtnet1.30`, or whatever the tag suffix renders
   as) to its own logical interface, and give each the static address from
   `docs/network-design.md`'s address table — `10.10.10.1/24`, `10.10.20.1/24`,
   `10.10.30.1/24`. Naming the assigned interfaces `MGMT`/`SERVERS`/`CLIENTS`
   (rather than the default `OPT1`/`OPT2`/`OPT3`) makes every later step, and
   every firewall rule, far easier to read.

Environment variables the code half (3b) expects to already be set:

| Variable | Used by | Value |
| --- | --- | --- |
| `PROXMOX_VE_ENDPOINT` | `terraform/` | the Proxmox API URL |
| `PROXMOX_VE_API_TOKEN` | `terraform/` | the Proxmox API token from step above (Milestone 4's own bootstrap, not this one) |
| `OPNSENSE_URI` | `opnsense/` | `https://` + OPNsense's Management address, `10.10.10.1` |
| `OPNSENSE_API_KEY` | `opnsense/` | the key from step 5 |
| `OPNSENSE_API_SECRET` | `opnsense/` | the secret from step 5 |

### 3b. Code — VLANs, DHCP, firewall

Two roots, and they apply in a fixed order — `opnsense/` cannot run before 3a's
manual steps give it an API to talk to, and its own VLAN devices don't exist
for step 6 of 3a to assign until this runs once.

1. `terraform apply` in `terraform/` (already done, to bring the OPNsense VM
   up — see 3a step 1). Nothing else in this root exists yet; Milestone 5 adds
   the three Windows guests to it.
2. Complete 3a steps 2–5 (install, WAN assignment, enable the API).
3. `terraform init && terraform apply` in `opnsense/` — creates the three VLAN
   devices, the Clients DHCP scope, the aliases, every filter rule and the
   outbound NAT rule.
4. Complete 3a step 6 (assign each VLAN device to an interface, address it).
5. Verify: from a host on each VLAN, confirm it can reach its gateway and (for
   Clients) that it received a DHCP lease with DC01 as its DNS server. Full
   client-to-DC01 and domain verification waits for Milestone 6 — Milestone 5
   only brings DC01 up as a VM, with no domain yet to test against.

Re-running `terraform apply` in `opnsense/` after a change is safe and expected
— unlike the Packer templates, this root's resources are meant to be updated in
place, not replaced.

**CI:** the Terraform job in `.github/workflows/validate.yml` already matrixes
over both `terraform/` and `opnsense/` (added in Milestone 2, before either root
held anything), so no workflow change was needed to cover this milestone's new
resources — confirmed by pushing this milestone's real code and watching both
matrix legs go green, then deliberately breaking one resource on a throwaway
branch and watching that leg go red before reverting.

## 4. DC01 — domain controller

**Never executed.** Depends on section 3 being fully done first — no gateway, no
DHCP reservation and no DNS path exist until the firewall is bootstrapped and
its VLAN devices are assigned and addressed.

1. `terraform apply` in `terraform/`, targeted at just DC01 first
   (`-target=proxmox_virtual_environment_vm.dc01`) rather than all four guests
   at once — DC01 has to exist and be reachable before SRV01/CL01's own applies
   would mean anything, since they join a domain DC01 hasn't created yet.
2. Proxmox clones the template, boots DC01, and it picks up its DHCP
   reservation (`10.10.20.10` — `opnsense/dhcp.tf`). Terraform's WinRM
   connection waits on exactly that address; if the reservation is missing or
   the MAC doesn't match `docs/conventions.md`, this is where it hangs.
3. Terraform uploads `powershell/` and runs `Bootstrap-DC01.ps1` — this script
   does not exist yet (Milestone 6), so this step is unexecuted twice over:
   no host, and no script.
4. Once Milestone 6 exists: confirm AD DS, DNS and the OU structure from
   `docs/ad-design.md` are up, and that DC01 now answers on its address
   *statically* — the DHCP reservation was only ever how it got there the
   first time.

## 5. SRV01 and CL01 — join the domain

**Never executed.** Depends on section 4 being complete — a domain that
doesn't exist yet has nothing to join.

1. `terraform apply` in `terraform/` again, this time for the remaining two
   guests (or the whole root — DC01's apply is now a no-op). Both can go in
   the same apply; neither depends on the other, only on DC01.
2. Each picks up its own DHCP reservation (`10.10.20.11` for SRV01,
   `10.10.30.50` for CL01) and gets its `Bootstrap-SRV01.ps1` /
   `Bootstrap-CL01.ps1` run over WinRM — neither script exists yet, same
   double-unexecuted caveat as section 4.
3. Once Milestone 6 exists: confirm both show up as domain-joined computer
   objects in the OUs `docs/ad-design.md` specifies (`Computers/Servers` for
   SRV01, `Computers/Workstations` for CL01), and that CL01's logon screen
   shows the Workstation Baseline GPO's banner — the one visible proof point
   the whole lab has been building toward since Milestone 1.

## 6. Full rebuild, start to finish

*(Milestone 8 — not started. Will cover: tearing everything down and replaying
sections 1–5 in order from a clean host, as the final proof the repo is complete.)*
