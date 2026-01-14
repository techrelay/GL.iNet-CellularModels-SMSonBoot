#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

if [ -x /etc/init.d/sms_on_boot ]; then
  /etc/init.d/sms_on_boot disable || true
fi

rm -f /etc/init.d/sms_on_boot
rm -f /usr/bin/sms_on_boot.sh
rm -f /etc/sms_on_boot.last

echo "[OK] Uninstalled."
