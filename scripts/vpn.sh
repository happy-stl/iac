#!/usr/bin/env bash
#
# Bring the WireGuard VPN up/down on this Mac using wg-quick.
#
# Requires: brew install wireguard-tools
# Usage:
#   ./scripts/vpn.sh up       # connect
#   ./scripts/vpn.sh down     # disconnect
#   ./scripts/vpn.sh status   # show tunnel status
#
# Config path defaults to environments/do/vpn/generated/wireguard-client.conf
#
# Override the config path with WG_CONF, e.g.:
#   WG_CONF=/path/to/wireguard-client.conf ./scripts/vpn.sh up

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WG_CONF="${WG_CONF:-$SCRIPT_DIR/../environments/do/vpn/generated/wireguard-client.conf}"

if ! command -v wg-quick >/dev/null 2>&1; then
  echo "wg-quick not found. Install with: brew install wireguard-tools" >&2
  exit 1
fi

if [[ ! -f "$WG_CONF" ]]; then
  echo "Config not found: $WG_CONF" >&2
  echo "Run 'terraform apply' in environments/do/vpn first, or set WG_CONF." >&2
  exit 1
fi

cmd="${1:-}"
case "$cmd" in
  up)     sudo wg-quick up "$WG_CONF" ;;
  down)   sudo wg-quick down "$WG_CONF" ;;
  status) sudo wg show ;;
  *)
    echo "Usage: $0 {up|down|status}" >&2
    exit 1
    ;;
esac
