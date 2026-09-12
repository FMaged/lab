---
name: github-actions-ci
description: Conventions and known gotchas for this repo's validation harness in .github/workflows/validate.yml — the only feedback loop this project has, since nothing can be applied locally. Use when editing the workflow, adding a new validation job, a provider/plugin pin, or debugging a red CI run. Not for the Terraform/Packer/OPNsense conventions themselves — see terraform-proxmox, terraform-opnsense and packer-windows for those.
---

# GitHub Actions CI conventions for the SI lab

`validate.yml` is the project's only feedback loop (see the CI decision in
`PLAN.md`) — it validates and never applies, holds no credentials, and every layer
must stay fmt-clean and validate-clean against it.

## Conventions

- **Checking `fmt` before pushing, without installing Terraform or Packer:** both
  tools' `fmt` share the exact same HCL2 formatter (`hashicorp/hcl`'s `hclwrite`),
  so `terraform fmt` also correctly formats `.pkr.hcl` files — they just have to be
  named `.tf` while it runs, since `terraform fmt` rejects any other extension.
  Download the `terraform` zip for `linux_amd64` straight from
  `releases.hashicorp.com` into the scratchpad (~120 MB unpacked, well inside the
  ~1 GB free), copy the target `.hcl`/`.pkr.hcl` files there under a `.tf` name,
  run `terraform fmt -diff` to see what's wrong or plain `fmt` to fix it, copy the
  result back over the real files, then delete the whole scratch directory
  (binary included) so nothing permanent lands on the 98%-full disk. This is how
  Milestone 3's `tags` alignment bug in the two Packer source files was actually
  found, after two blind guesses at the alignment by eye both missed it.
- Every job checks out with `actions/checkout@v7` — GitHub removes Node 20 from
  Actions runners on 2026-09-16, and older major versions of both `checkout` and
  several other actions used here (`hashicorp/setup-terraform`, `hashicorp/setup-packer`)
  are Node-20-only as of this writing. `checkout` has a Node-24 major (v7); the two
  HashiCorp actions do not yet — there is nothing to pin to until upstream ships one,
  so this is a known, unresolved risk, not a gap to fix now.
- A check that cannot run yet prints an explicit `::notice::` explaining why, never
  a silent skip — a silently-green job for the wrong reason is worse than no job.
  This applied to `packer validate` through Milestone 2 (no build template existed
  yet); Milestone 3 added real build blocks and removed that gate, so it now runs
  unconditionally like every other check.
- `Invoke-ScriptAnalyzer` has **no `-Include` parameter** — that belongs to
  `Get-ChildItem`. To restrict analysis to `*.ps1`/`*.psm1` (and keep
  `PSScriptAnalyzerSettings.psd1` itself out of analysis — `-Path powershell -Recurse`
  alone sweeps it up as a `.psd1` file), filter with `Get-ChildItem -Recurse -Include
  *.ps1, *.psm1` first and pipe the results into `Invoke-ScriptAnalyzer`. Passing
  `-Include` straight to `Invoke-ScriptAnalyzer` fails immediately with "Parameter
  cannot be processed because the parameter name 'Include' is ambiguous" (it partially
  matches `-IncludeDefaultRules`/`-IncludeRule`/`-IncludeSuppressed`) — this is a
  parameter-binding error, not a lint finding, so it fails before analyzing anything.
- The terraform matrix (`terraform`/`opnsense`) sets `fail-fast: false`. Without it,
  a fmt/validate break in one directory cancels the other directory's job
  mid-run — it never gets the chance to fail (or pass) on its own merits, so a real
  problem in `opnsense/` could hide behind an unrelated one in `terraform/`.
- Only `push` to `main` and `pull_request` trigger this workflow — pushing a branch
  on its own does **not** run it. To see CI on a branch before merging, open a PR
  against `main`; closing/deleting the branch without merging closes the PR too.

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
- **2026-09-12, lychee link check:** `lycheeverse/lychee-action@v2` failed at
  `curl -sfLO` with exit code 35 — a TLS handshake error while downloading its own
  release binary, not a 404 and nothing to do with the repository's links. Replaced
  with `.github/scripts/check-markdown-links.py` rather than retried: the job passed
  `--exclude '^https?://'`, so it was downloading 20 MB to check relative links that
  need no network at all. The general rule this suggests: a check in this harness
  should not depend on a download unless the check genuinely needs the network, since
  a third party's bad minute is otherwise indistinguishable from a real failure.
- When a job goes red with no clear cause and `/actions/jobs/{id}/logs` 403s ("Must
  have admin rights to Repository"), make the step self-diagnosing (try/catch,
  `Write-Output "::error::<real exception message>"`) rather than guessing twice —
  the annotations at `/repos/{owner}/{repo}/check-runs/{id}/annotations` surface
  whatever that step writes, without needing admin auth.
- **2026-09-11, task 8 (proving the harness fails):** a test secret-scan commit
  using AWS's own `AKIAIOSFODNN7EXAMPLE` placeholder key did **not** trip gitleaks —
  it's on gitleaks' default allowlist by design, since that exact string appears in
  thousands of docs and would otherwise be permanent noise. To actually test the
  rule, use a fake-but-different AWS-shaped key (same `AKIA` + 20-char pattern),
  never the well-known example value.
- Pushing a branch does not run this workflow (see the trigger convention above) —
  the first attempt at task 8 pushed straight to a branch and got no run at all
  until a PR was opened against `main`.
