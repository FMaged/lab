---
name: github-actions-ci
description: Conventions and known gotchas for this repo's validation harness in .github/workflows/validate.yml — the only feedback loop this project has, since nothing can be applied locally. Use when editing the workflow, adding a new validation job, a provider/plugin pin, or debugging a red CI run. Not for the Terraform/Packer/OPNsense conventions themselves — see terraform-proxmox, terraform-opnsense and packer-windows for those.
---

# GitHub Actions CI conventions for the SI lab

`validate.yml` is the project's only feedback loop (see the CI decision in
`PLAN.md`) — it validates and never applies, holds no credentials, and every layer
must stay fmt-clean and validate-clean against it.

## Conventions

- Every job checks out with `actions/checkout@v7` — GitHub removes Node 20 from
  Actions runners on 2026-09-16, and older major versions of both `checkout` and
  several other actions used here (`hashicorp/setup-terraform`, `hashicorp/setup-packer`)
  are Node-20-only as of this writing. `checkout` has a Node-24 major (v7); the two
  HashiCorp actions do not yet — there is nothing to pin to until upstream ships one,
  so this is a known, unresolved risk, not a gap to fix now.
- A check that cannot run yet (`packer validate` before a build template exists in
  Milestone 3) prints an explicit `::notice::` explaining why, never a silent skip —
  see the packer job. A silently-green job for the wrong reason is worse than no job.
- `Invoke-ScriptAnalyzer -Recurse` over `powershell/` must use
  `-Include *.ps1, *.psm1`. Without it, `-Recurse` sweeps up
  `PSScriptAnalyzerSettings.psd1` itself and lints it as a script — a settings file
  is configuration for the analyzer, not something the analyzer should judge.

## Gotchas

- **2026-09-11, first real push:** `gitleaks/gitleaks-action@v2` failed on the very
  first CI run. Its own repo documents that v2 stops working once Node 20 is
  removed (2026-09-16) "regardless of any opt-out flag" — v3 is a drop-in
  replacement with no input/behavior changes, just the Node 24 runtime. No license
  key is needed either way on a personal-account public repo.
- If a job goes red with no clear cause and the logs 403 ("Must have admin rights to
  Repository"), that's the GitHub API's job-log endpoint requiring repo-admin auth —
  it's not fetchable anonymously even on a public repo. Diagnose from the Actions
  web UI instead, or from what's independently verifiable (job/step conclusions via
  the public `/actions/runs` API, upstream changelogs and issue trackers).
