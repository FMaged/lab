#!/usr/bin/env python3
"""Fail if any relative link or heading anchor in the Markdown is broken.

Deliberately does not touch the network. The previous check downloaded a release
binary on every run and then excluded external links anyway, which made the
project's only feedback loop depend on a download it did not need — it failed once
on a TLS error with nothing wrong in the repository.

Checks two things the docs actually rely on: that every relative link resolves to a
file that exists, and that every "#anchor" matches a heading in the file it points
at. The second is what keeps the generated decision index in PLAN.md honest.

External links are not checked. Nothing here links out to anything load-bearing, and
a third party's outage must never turn this build red.

Run locally with: python3 .github/scripts/check-markdown-links.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SKIP_DIRS = {".git", ".terraform", "packer_cache", "node_modules"}

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
HEADING_RE = re.compile(r"^#{1,6}\s+(.+?)\s*$")


def slug(text):
    """GitHub's heading slug: lowercase, drop punctuation, spaces to hyphens."""
    text = text.lower()
    text = "".join(c for c in text if c.isalnum() or c in " -")
    return text.replace(" ", "-")


def anchors(path):
    found = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = HEADING_RE.match(line)
        if match:
            found.add(slug(match.group(1)))
    return found


def main():
    failures = []
    checked = 0

    files = sorted(
        p for p in ROOT.rglob("*.md")
        if not SKIP_DIRS & set(p.relative_to(ROOT).parts)
    )

    for path in files:
        rel = path.relative_to(ROOT)
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for target in LINK_RE.findall(line):
                if target.startswith(("http://", "https://", "mailto:", "tel:")):
                    continue
                checked += 1
                filepart, _, anchor = target.partition("#")
                dest = (path.parent / filepart).resolve() if filepart else path
                if not dest.exists():
                    failures.append((rel, lineno, target, "no such file"))
                    continue
                if anchor and dest.suffix == ".md" and anchor not in anchors(dest):
                    failures.append((rel, lineno, target, "no such heading in %s"
                                     % dest.relative_to(ROOT)))

    if not failures:
        print("markdown links: %d relative link(s) across %d file(s), none broken."
              % (checked, len(files)))
        return 0

    for rel, lineno, target, why in failures:
        print("::error file=%s,line=%d::broken link %s — %s" % (rel, lineno, target, why))
    print("\n%d broken link(s)." % len(failures))
    return 1


if __name__ == "__main__":
    sys.exit(main())
