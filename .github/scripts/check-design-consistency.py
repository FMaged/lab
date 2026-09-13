#!/usr/bin/env python3
"""Fail if the code disagrees with the design documents about MACs or addresses.

The MAC address is the interface between the two Terraform roots: terraform/ pins it
on a VM's NIC and opnsense/ keys a DHCP reservation on it. Change one side alone and
the guest boots unreachable, with nothing in a plan or a validate run to explain why.
The same values are also written by hand in terraform/outputs.tf, a third place.

Rather than compare the roots to each other, every literal is checked against the
design document that owns it. AGENTS.md already requires changing the document first,
so anchoring there means the roots agree with each other as a consequence, and a
value invented in code fails even if both roots happen to share the invention.

Run locally with: python3 .github/scripts/check-design-consistency.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

# What owns which kind of value.
OWNERS = {
    "mac": ROOT / "docs" / "conventions.md",
    "ip": ROOT / "docs" / "network-design.md",
}

# Where the values get used. packer/ and proxmox/ joined in Milestone 9, once
# packer/files/config.xml and proxmox/answer.toml started carrying real
# addresses baked in at build time instead of a person typing them by hand.
# scripts/ joined in Milestone 10, once the host-side runner started carrying
# 10.10.10.2 and the guests' own addresses as literals of its own.
CODE_DIRS = ("terraform", "opnsense", "packer", "proxmox", "scripts")
CODE_SUFFIXES = (".tf", ".pkr.hcl", ".xml", ".toml", ".sh")

MAC_RE = re.compile(r"\b([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})\b")
# Lab address space only. The WAN side is a real home or provider network and is
# deliberately not pinned in the design.
IP_RE = re.compile(r"\b(10\.10\.\d{1,3}\.\d{1,3})\b")


def owner_text(kind):
    path = OWNERS[kind]
    if not path.exists():
        sys.exit("design document missing: %s" % path.relative_to(ROOT))
    return path.read_text(encoding="utf-8")


def main():
    macs = owner_text("mac").lower()
    ips = owner_text("ip")
    failures = []

    for directory in CODE_DIRS:
        base = ROOT / directory
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or not path.name.endswith(CODE_SUFFIXES):
                continue
            rel = path.relative_to(ROOT)
            for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                # MACs are compared case-insensitively on purpose: terraform/ writes
                # them uppercase and opnsense/ lowercase, which DHCP does not care
                # about and which is not worth a failing build.
                for mac in MAC_RE.findall(line):
                    if mac.lower() not in macs:
                        failures.append((rel, lineno, "MAC", mac, "docs/conventions.md"))
                for ip in IP_RE.findall(line):
                    if ip not in ips:
                        failures.append((rel, lineno, "address", ip, "docs/network-design.md"))

    if not failures:
        print("design consistency: every MAC and lab address in %s matches its design document."
              % " and ".join(d + "/" for d in CODE_DIRS))
        return 0

    for rel, lineno, kind, value, doc in failures:
        print("::error file=%s,line=%d::%s %s is not in %s. Change the design document "
              "first, then the code — see AGENTS.md." % (rel, lineno, kind, value, doc))
    print("\n%d value(s) in code disagree with the design documents." % len(failures))
    return 1


if __name__ == "__main__":
    sys.exit(main())
