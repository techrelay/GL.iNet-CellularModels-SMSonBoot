#!/bin/sh
set -eu

PHONE="${1:-}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root" >&2
  exit 1
fi

if ! command -v sendsms >/dev/null 2>&1; then
  echo "ERROR: sendsms not found (GL.iNet firmware required)" >&2
  exit 1
fi

# Install main script
cp ./files/usr/bin/sms_on_boot.sh /usr/bin/sms_on_boot.sh
chmod +x /usr/bin/sms_on_boot.sh

# Optionally set phone number
if [ -n "$PHONE" ]; then
  sed -i "s|^PHONE=\".*\"|PHONE=\"$PHONE\"|g" /usr/bin/sms_on_boot.sh
fi

# Create init.d service (OpenWrt-native way)
cat > /etc/init.d/sms_on_boot <<'EOF'
#!/bin/sh /etc/rc.common
START=99
start() {
  /usr/bin/sms_on_boot.sh &
}
EOF

chmod +x /etc/init.d/sms_on_boot
/etc/init.d/sms_on_boot enable

echo "[OK] sms_on_boot installed"
echo "Test with:"
echo "  rm -f /etc/sms_on_boot.last && /usr/bin/sms_on_boot.sh"
