variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL, e.g. https://proxmox.example.internal:8006/api2/json"
  # Placeholder, not real — packer validate requires this non-empty, and
  # there's no host to point it at yet regardless. Matches example.pkrvars.hcl.
  default = "https://proxmox.example.internal:8006/api2/json"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name the templates are built on"
  default     = "pve" # placeholder — same reasoning as proxmox_url above.
}

variable "proxmox_api_token_id" {
  type        = string
  description = "Proxmox API token ID, e.g. root@pam!packer"
  default     = "root@pam!packer" # placeholder — same reasoning as proxmox_url above.
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "Proxmox API token secret"
  # "REPLACE_ME", not empty — same reasoning as proxmox_url above. Not a real
  # secret; sensitive = true is what actually matters here.
  default   = "REPLACE_ME"
  sensitive = true
}

variable "iso_datastore" {
  type        = string
  description = "Datastore that holds installation and VirtIO ISOs"
  default     = "local"
}

variable "template_datastore" {
  type        = string
  description = "Datastore for template disks, the EFI disk and TPM state"
  default     = "local-lvm"
}

variable "win_server_iso_file" {
  type        = string
  description = "ISO filename on iso_datastore — see the Packer templates table in docs/conventions.md"
  default     = "win-server-2025-de.iso"
}

variable "win_server_iso_checksum" {
  type        = string
  description = "sha256:<hash> for win_server_iso_file — \"none\" until the real ISO is uploaded and checksummed"
  default     = "none"
}

variable "win11_iso_file" {
  type        = string
  description = "ISO filename on iso_datastore — see the Packer templates table in docs/conventions.md"
  default     = "win-11-pro-de.iso"
}

variable "win11_iso_checksum" {
  type        = string
  description = "sha256:<hash> for win11_iso_file — \"none\" until the real ISO is uploaded and checksummed"
  default     = "none"
}

variable "virtio_iso_file" {
  type        = string
  description = "Version-pinned VirtIO driver ISO filename on iso_datastore — no \"latest\" alias, per docs/conventions.md"
  default     = "virtio-win-0.1.285.iso"
}

variable "virtio_iso_checksum" {
  type        = string
  description = "sha256:<hash> for virtio_iso_file — \"none\" until the real ISO is uploaded and checksummed"
  default     = "none"
}

variable "local_admin_password" {
  type        = string
  description = "Local administrator password baked into both answer files"
  default     = ""
  sensitive   = true
}
