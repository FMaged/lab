# Copy to opnsense.auto.tfvars (gitignored) and adjust if your trunk NIC device
# name or VLAN IDs differ from the defaults. Connection credentials are NOT
# here — set OPNSENSE_URI, OPNSENSE_API_KEY and OPNSENSE_API_SECRET as
# environment variables instead. See the secrets decision in PLAN.md.

trunk_parent_interface = "vtnet1"

network_vlan_management = 10
network_vlan_servers    = 20
network_vlan_clients    = 30
