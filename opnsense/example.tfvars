# Copy to opnsense.auto.tfvars (gitignored) and adjust if your VLAN IDs differ
# from the defaults. No credentials here — the OPNsense URI, key and secret
# live in the root .env. See example.env and the secrets decision in PLAN.md.

network_vlan_management = 10
network_vlan_servers    = 20
network_vlan_clients    = 30
