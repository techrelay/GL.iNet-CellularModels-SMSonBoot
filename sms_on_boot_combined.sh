#!/bin/sh
LOG="/tmp/sms_on_boot_combined.log"
STATE="/etc/sms_on_boot_combined.last"
COOLDOWN=1800

PHONE="+11234567890"
PREFER="textbelt"            # "textbelt" or "sendsms"
TEXTBELT_KEY="YOUR_KEY_HERE" # set if using textbelt (or "textbelt" free key)

log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

find_wan_iface() {
  dev="$(ip route 2>/dev/null | awk '/^default /{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
  if [ -n "$dev" ]; then
    case "$dev" in
      lo|br-lan|lan*|eth*|en*|wl*|wlan*|phy*|ap*|bat*|ifb*|docker*|veth*|tun*|wg*|tailscale* ) ;;
      *) echo "$dev"; return 0 ;;
    esac
  fi

  for dev in $(ls /sys/class/net 2>/dev/null); do
    case "$dev" in
      wan*|ppp*|wwan*|usb*|rmnet*|mhi*|cdc*|en*|eth* )
        ip -4 addr show dev "$dev" 2>/dev/null | grep -q "inet " && { echo "$dev"; return 0; }
        ;;
    esac
  done
  return 1
}

send_textbelt() {
  # requires curl + TEXTBELT_KEY
  if ! command -v curl >/dev/null 2>&1; then
    log "Textbelt: curl not found"
    return 1
  fi
  if [ -z "$TEXTBELT_KEY" ] || [ "$TEXTBELT_KEY" = "YOUR_KEY_HERE" ]; then
    log "Textbelt: TEXTBELT_KEY not set"
    return 1
  fi

  RESP="$(curl -sS -X POST https://textbelt.com/text \
    --data-urlencode phone="$PHONE" \
    --data-urlencode message="$MSG" \
    -d key="$TEXTBELT_KEY" 2>>"$LOG" || true)"

  echo "[$(date '+%F %T')] Textbelt response: $RESP" >> "$LOG"
  echo "$RESP" | grep -q '"success":[[:space:]]*true'
}

send_sendsms() {
  if ! command -v sendsms >/dev/null 2>&1; then
    log "sendsms: sendsms not found"
    return 1
  fi
  sendsms "$PHONE" "$MSG" international >/dev/null 2>&1
}

# Cooldown guard
now="$(date +%s)"
if [ -f "$STATE" ]; then
  last="$(cat "$STATE" 2>/dev/null | tr -dc '0-9')"
  if [ -n "$last" ] && [ $((now-last)) -lt "$COOLDOWN" ]; then
    log "Cooldown active ($((now-last))s < ${COOLDOWN}s), skipping."
    exit 0
  fi
fi

# If sendsms might be used, wait a bit for SMS services
i=0
while [ $i -lt 60 ]; do
  pidof sms_manager >/dev/null 2>&1 && pidof smsd >/dev/null 2>&1 && break
  sleep 2
  i=$((i+1))
done

WAN_IFACE="$(find_wan_iface 2>/dev/null || true)"
WAN_IP=""
if [ -n "$WAN_IFACE" ]; then
  WAN_IP="$(ip -4 addr show dev "$WAN_IFACE" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
fi

MSG="GL.iNet router booted after power outage.
Time: $(date '+%F %T %Z')"
[ -n "$WAN_IFACE" ] && MSG="$MSG
WAN IF: $WAN_IFACE"
[ -n "$WAN_IP" ] && MSG="$MSG
WAN IP: $WAN_IP"

log "Preferred provider: $PREFER"

if [ "$PREFER" = "textbelt" ]; then
  log "Trying Textbelt first..."
  if send_textbelt; then
    log "Sent via Textbelt"
    echo "$now" > "$STATE"
    exit 0
  fi
  log "Textbelt failed, trying sendsms..."
  if send_sendsms; then
    log "Sent via sendsms"
    echo "$now" > "$STATE"
    exit 0
  fi
else
  log "Trying sendsms first..."
  if send_sendsms; then
    log "Sent via sendsms"
    echo "$now" > "$STATE"
    exit 0
  fi
  log "sendsms failed, trying Textbelt..."
  if send_textbelt; then
    log "Sent via Textbelt"
    echo "$now" > "$STATE"
    exit 0
  fi
fi

log "All providers failed."
exit 1
