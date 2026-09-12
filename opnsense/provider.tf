provider "opnsense" {
  # uri, api_key and api_secret all come from OPNSENSE_URI, OPNSENSE_API_KEY
  # and OPNSENSE_API_SECRET — the provider reads these itself when the block
  # omits them. Never put a real URI or credential here. See the secrets
  # decision in PLAN.md and runbook section 3a for where the key comes from.
}
