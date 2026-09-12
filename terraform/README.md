# terraform/

Creates all four VMs with the bpg/proxmox provider: DC01, SRV01 and CL01 cloned
from the Packer templates, plus the OPNsense firewall booted from its installer
ISO. See the `terraform-proxmox` skill for conventions and constraints.
