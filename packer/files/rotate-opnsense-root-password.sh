#!/bin/sh
# Must run last: OPNsense re-applies config.xml's stored hash to the OS user table on every boot,
# so the live password and the stored hash need updating together or a later reboot reverts it.
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

# BSD sed, not GNU: -i takes the backup-suffix argument explicitly, even when empty.
sed -i '' "s|<password>${BOOTSTRAP_HASH}</password>|<password>${real_hash}</password>|" /conf/config.xml

echo "${ROOT_PASSWORD}" | pw usermod root -h 0

echo 'root password rotated to the real value. Build finished.'
