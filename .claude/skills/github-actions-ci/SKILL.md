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
- `Invoke-ScriptAnalyzer` has **no `-Include` parameter** — that belongs to
  `Get-ChildItem`. To restrict analysis to `*.ps1`/`*.psm1` (and keep
  `PSScriptAnalyzerSettings.psd1` itself out of analysis — `-Path powershell -Recurse`
  alone sweeps it up as a `.psd1` file), filter with `Get-ChildItem -Recurse -Include
  *.ps1, *.psm1` first and pipe the results into `Invoke-ScriptAnalyzer`. Passing
  `-Include` straight to `Invoke-ScriptAnalyzer` fails immediately with "Parameter
  cannot be processed because the parameter name 'Include' is ambiguous" (it partially
  matches `-IncludeDefaultRules`/`-IncludeRule`/`-IncludeSuppressed`) — this is a
  parameter-binding error, not a lint finding, so it fails before analyzing anything.

## Gotchas

- **2026-09-11, first real push:** `gitleaks/gitleaks-action@v2` failed on the very
  first CI run. Its own repo documents that v2 stops working once Node 20 is
  removed (2026-09-16) "regardless of any opt-out flag" — v3 is a drop-in
  replacement with no input/behavior changes, just the Node 24 runtime. No license
  key is needed either way on a personal-account public repo.
- **2026-09-11, same run:** the PSScriptAnalyzer job also failed, for an unrelated
  reason — see the `-Include` gotcha above. Took two attempted fixes to find: the
  first attempt guessed `-Include` was valid on `Invoke-ScriptAnalyzer` (it isn't)
  and introduced this exact bug; the real error only became visible once the step
  was wrapped in try/catch with `Write-Output "::error::..."` (not `Write-Host`) and
  the user read the raw log from the GitHub UI — the API's job-log endpoint 403s
  without repo-admin auth even on a public repo, so that path is a dead end for
  diagnosing CI from here without help.
- When a job goes red with no clear cause and `/actions/jobs/{id}/logs` 403s ("Must
  have admin rights to Repository"), make the step self-diagnosing (try/catch,
  `Write-Output "::error::<real exception message>"`) rather than guessing twice —
  the annotations at `/repos/{owner}/{repo}/check-runs/{id}/annotations` surface
  whatever that step writes, without needing admin auth.
