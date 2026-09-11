# Network diagram

Addresses and VLAN IDs match `docs/network-design.md` — this is the picture of that
table, not a second source of truth.

```mermaid
flowchart TB
    internet(("Internet"))
    home["Home router\n192.168.1.0/24"]
    internet --- home

    subgraph proxmox["Proxmox host — 10.10.10.2"]
        opn["OPNsense\nWAN + VLANs 10/20/30"]
        dc01["DC01\n10.10.20.10\nAD DS, DNS"]
        srv01["SRV01\n10.10.20.11\nmember server"]
        cl01["CL01\nVLAN 30, DHCP\nWindows 11"]
    end

    home -- "WAN, DHCP" --- opn

    opn -- "VLAN 10 (Mgmt)\n10.10.10.0/24" --- proxmox
    opn -- "VLAN 20 (Servers)\n10.10.20.0/24" --- dc01
    opn -- "VLAN 20 (Servers)\n10.10.20.0/24" --- srv01
    opn -- "VLAN 30 (Clients)\n10.10.30.0/24" --- cl01

    dc01 -. "domain join + GPO" .-> srv01
    dc01 -. "domain join + GPO" .-> cl01
```
