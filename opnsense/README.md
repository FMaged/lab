# opnsense/

Kea DHCP, firewall rules and NAT as Terraform resources against the
browningluke/opnsense provider. Interface assignment, VLAN devices and the API
credential are baked into `tpl-opnsense-v1` at build time instead
(`packer/files/config.xml`) — see the `terraform-opnsense` skill and the
zero-touch decision in PLAN.md.
