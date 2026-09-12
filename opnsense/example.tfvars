# Copy to opnsense.auto.tfvars (gitignored) and adjust if your trunk NIC device
# name or VLAN IDs differ from the defaults. No credentials here — the OPNsense
# URI, key and secret live in the root .env. See example.env and the secrets
# decision in PLAN.md.

trunk_parent_interface = "vtnet1"

network_vlan_management = 10
network_vlan_servers    = 20
network_vlan_clients    = 30
