#!/bin/sh
# Must run last — the login OPNsense's installer accepted was the fixed
# bootstrap password baked into config.xml, and OPNsense re-applies
# config.xml's stored hash to the OS user table on every boot. Both the live
# OS password and the stored hash need updating together, or a later reboot
# (Terraform's first clone included) would silently revert to the bootstrap
# value.
set -eu

if [ -z "${ROOT_PASSWORD:-}" ]; then
  echo "ROOT_PASSWORD environment variable is not set" >&2
  exit 1
fi
if [ -z "${BOOTSTRAP_HASH:-}" ]; then
  echo "BOOTSTRAP_HASH environment variable is not set" >&2
  exit 1
fi

real_hash=$(openssl passwd -6 "${ROOT_PASSWORD}")

# BSD sed, not GNU: -i takes the backup-suffix argument explicitly, even when
# it's empty. The bootstrap hash is a fixed, non-secret literal (the same one
# config.xml was rendered with), so an exact-string match is safe here.
sed -i '' "s|<password>${BOOTSTRAP_HASH}</password>|<password>${real_hash}</password>|" /conf/config.xml

echo "${ROOT_PASSWORD}" | pw usermod root -h 0

echo 'root password rotated to the real value. Build finished.'
