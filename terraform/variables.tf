variable "proxmox_node" {
  type        = string
  description = "Proxmox node name the guests are created on"
  default     = "pve" # placeholder — see the secrets/placeholder reasoning in packer/variables.pkr.hcl.
}

variable "iso_datastore" {
  type        = string
  description = "Datastore holding the OPNsense installation ISO"
  default     = "local"
}

variable "guest_datastore" {
  type        = string
  description = "Datastore for guest disks"
  default     = "local-lvm"
}

variable "network_vlan_management" {
  type        = number
  description = "VLAN ID for the Management network — see docs/network-design.md"
  default     = 10
}

variable "network_vlan_servers" {
  type        = number
  description = "VLAN ID for the Servers network — see docs/network-design.md"
  default     = 20
}

variable "network_vlan_clients" {
  type        = number
  description = "VLAN ID for the Clients network — see docs/network-design.md"
  default     = 30
}

variable "proxmox_bridge_wan" {
  type        = string
  description = "Proxmox bridge for OPNsense's WAN uplink — see docs/hardware.md's two NIC layouts"
  default     = "vmbr0"
}

variable "proxmox_bridge_trunk" {
  type        = string
  description = "Proxmox bridge carrying the tagged VLAN trunk (10/20/30) — see docs/hardware.md"
  default     = "vmbr1"
}

# No default on either — genuinely required, unlike the placeholders above.
# terraform validate (unlike packer validate) does not need one; a real value
# is only needed at apply, which nothing here can do yet anyway.

variable "local_admin_password" {
  type        = string
  description = "The local Administrator password baked into the templates — set by Packer's rotate-admin-password.ps1, matched here so Terraform's WinRM connection can authenticate"
  sensitive   = true
}

variable "domain_admin_password" {
  type        = string
  description = "Domain administrator password, for SRV01/CL01's eventual domain join — consumed by the powershell/ entry point, not by Terraform itself"
  sensitive   = true
}

variable "dsrm_recovery_password" {
  type        = string
  description = "Directory Services Restore Mode password for DC01's Install-ADDSForest call — a separate credential from local_admin_password and domain_admin_password, consumed once during promotion and by no other guest"
  sensitive   = true
}
