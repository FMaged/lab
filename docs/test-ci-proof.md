# CI-proving test file

Throwaway file for task 8 in TASKS.md — proves the validation harness actually
catches problems, rather than passing on an empty directory for the wrong reason.
This file (and the branch it lives on) is deleted without merging once every check
has been observed failing for the right reason.

A dead relative link, to trip the markdown link checker: [nothing here](does-not-exist.md).

AWS's own EXAMPLE key turned out to be gitleaks' own allowlisted placeholder (by
design — it appears in thousands of docs, so gitleaks ignores it to cut noise), so
it does not prove the rule fires. This string matches the same AWS access-key
pattern without being that allowlisted value, and is not a real, functioning
credential: AKIA3TESTNOTREALFAKE
