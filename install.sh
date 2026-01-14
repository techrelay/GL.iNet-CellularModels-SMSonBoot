#!/bin/sh
set -eu

PHONE="${1:-}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root." >&2
  exit 1
fi

if ! command -v sendsms >/dev/null 2>&1; then
  echo "ERROR: sendsms not found. GL.iNet firmware required." >&2
  exit 1
fi

echo "[*] Downloading sms_on_boot.sh..."
curl -fsSL \
  https://raw.githubusercontent.com/zippyy/GL.iNet-CellularModels-SMSonBoot/main/sms_on_boot.sh \
  -o /usr/bin/sms_on_boot.sh

chmod +x /usr/bin/sms_on_boot.sh

if [ -n "$PHONE" ]; then
  sed -i "s|^PHONE=\".*\"|PHONE=\"$PHONE\"|g" /usr/bin/sms_on_boot.sh
  echo "[*] Set PHONE to: $PHONE"
else
  echo "[!] No phone provided. Edit /usr/bin/sms_on_boot.sh later."
fi

echo "[*] Creating init.d service..."
cat > /etc/init.d/sms_on_boot
