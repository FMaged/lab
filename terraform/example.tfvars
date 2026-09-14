# Copy to terraform.auto.tfvars (gitignored) and adjust if your Proxmox node,
# datastores or VLAN IDs differ from the defaults. No credentials here — the
# Proxmox endpoint and token, and all three guest passwords, live in the root
# .env. See example.env and the secrets decision in PLAN.md.

proxmox_node    = "pve"
guest_datastore = "local-lvm"

network_vlan_management = 10
network_vlan_servers    = 20
network_vlan_clients    = 30
