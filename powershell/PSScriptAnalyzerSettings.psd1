@{
    # Explicit severities, matched to the CI job — a future PSScriptAnalyzer release
    # adding a new default rule cannot turn this red without a version bump too,
    # since the workflow installs an exact -RequiredVersion.
    Severity     = @('Error', 'Warning')
    IncludeDefaultRules = $true
}
