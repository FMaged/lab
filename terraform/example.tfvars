# Copy to terraform.auto.tfvars (gitignored) and adjust if your Proxmox node,
# datastores or VLAN IDs differ from the defaults. Connection credentials are
# NOT here — set PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN as environment
# variables instead. See the secrets decision in PLAN.md.

proxmox_node    = "pve"
iso_datastore   = "local"
guest_datastore = "local-lvm"

network_vlan_management = 10
network_vlan_servers    = 20
network_vlan_clients    = 30
