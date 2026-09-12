# Walkthrough: one machine, end to end

Every other document here is reference or procedure. This one follows a single
machine — **CL01**, the Windows 11 workstation — from blank installation media to a
domain member displaying a Group Policy setting, and names the file responsible at
each step.

> **This describes a design, not a run.** No Proxmox host exists, so none of the
> steps below have been executed. See [Execution status](../README.md#execution-status).

CL01 is the machine worth following because it is the one that has to be handed an
address by something else, join a domain it does not know the location of, and end up
in the right place in the directory for a policy to reach it. The other three guests
are simpler versions of the same chain.

## 1. Packer bakes the image

[`packer/windows-11.pkr.hcl`](../packer/windows-11.pkr.hcl) builds a Proxmox template
from German Windows 11 media, answered by
[`packer/files/autounattend-client.xml`](../packer/files/autounattend-client.xml).

The answer file does four things and no more: partition the disk, inject the VirtIO
storage driver so Setup can see it at all, create a local administrator, and enable
WinRM. The VM gets a real TPM 2.0 and Secure Boot rather than registry bypasses,
because that is what Windows 11 Setup actually requires.

The image is deliberately **not** generalized — no sysprep. It also carries no
hostname, no address and no domain membership. Identity is not part of an image that
three machines share.

## 2. Terraform clones it and pins a MAC

[`terraform/vm-cl01.tf`](../terraform/vm-cl01.tf) clones that template into VM 301 on
the Clients VLAN, and does one thing that looks fussy and is not: it sets an explicit
MAC address, `02:00:00:00:01:2D`, derived from the VM ID in
[`docs/conventions.md`](conventions.md).

It also restates TPM and Secure Boot rather than trusting the clone to inherit them.
Proxmox drops Secure Boot silently on clone, and Windows 11 then fails to boot at all.

## 3. OPNsense answers with a reserved address

Here is the part that would otherwise be a gap. The template has no address, and the
machine cannot be reached to be given one.

[`opnsense/dhcp.tf`](../opnsense/dhcp.tf) holds a Kea reservation keyed on exactly the
MAC Terraform pinned, handing out `10.10.30.50` — outside the dynamic pool, so it can
never be issued to anything else — and naming DC01 at `10.10.20.10` as the DNS server.
A client that resolves through the firewall instead cannot find a domain controller.

The MAC is therefore an interface between two Terraform roots. Change it on one side
alone and CL01 boots unreachable, with nothing in a plan or a validation run to say
why.

## 4. Terraform hands off to PowerShell

With CL01 at a known address, Terraform uploads the whole `powershell/` directory to
`C:/lab-provisioning` and runs
[`powershell/Bootstrap-CL01.ps1`](../powershell/Bootstrap-CL01.ps1), passing the domain
credential as an argument. That is Terraform's last act for this guest. No Active
Directory work happens in Terraform.

## 5. The script joins the domain and reboots

The script waits for DC01 to answer, since a client booting before its domain
controller is a normal race rather than a failure.

Then one call does the whole job: `Add-Computer` with `-NewName` and `-OUPath` renames
the machine and joins it **directly into** `Computers/Workstations`. Joining first and
moving afterwards would leave it briefly in the default container, outside the scope of
the policy that is about to be applied to it.

The phase marker is written **before** that call, not after, because `-Restart` reboots
from inside it. A marker written afterwards would never be written at all, and the
machine would rejoin forever.

## 6. Resume, and the visible proof

The reboot drops the session. A scheduled task registered by
[`powershell/SILab.psm1`](../powershell/SILab.psm1) resumes the script on boot, finds
phase 1 already complete, unregisters itself and stops.

Note what the script does *not* do: carry the credential across that reboot. Nothing
writes it to disk. The join consumed it before the reboot that would have lost it,
which is why the phase order is the way it is.

CL01 now sits in `Computers/Workstations`, which is what puts it in scope of the
Workstation Baseline GPO from [`docs/ad-design.md`](ad-design.md). That policy sets a
logon banner — chosen deliberately as the one outcome visible in a screenshot of a
logon screen, rather than something only `gpresult` could confirm.

## 7. What made it possible

Steps 5 and 6 quietly depended on the firewall.
[`opnsense/firewall.tf`](../opnsense/firewall.tf) permits Clients to reach DC01 on
exactly DNS, Kerberos, LDAP, SMB and NTP — nothing else, and nothing at all toward the
Management VLAN. Those five are not a guess: they are what a domain member needs, and
the policy table in [`docs/network-design.md`](network-design.md) gives the reason for
each.

[`powershell/Test-SILab.ps1`](../powershell/Test-SILab.ps1) checks all of it read-only,
one assertion per row of the design documents.

## The same chain, compressed

| Step | File | What it settles |
| --- | --- | --- |
| 1 | `packer/windows-11.pkr.hcl` | An image exists, with no identity in it |
| 2 | `terraform/vm-cl01.tf` | A VM exists, on the right VLAN, with a known MAC |
| 3 | `opnsense/dhcp.tf` | That MAC gets a known address and the right DNS server |
| 4 | `terraform/vm-cl01.tf` | Scripts arrive and run, once |
| 5 | `powershell/Bootstrap-CL01.ps1` | The machine joins, in the right OU, first time |
| 6 | `powershell/SILab.psm1` | The reboot does not break the sequence |
| 7 | `opnsense/firewall.tf` | Steps 5 and 6 were permitted to happen |
