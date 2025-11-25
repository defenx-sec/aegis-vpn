#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Cleanup Script v1.3 (iptables mode)
#===========================================================

set -e

read -p "This will remove all Aegis-VPN configs. Continue? (y/N): " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

systemctl stop wg-quick@wg0 2>/dev/null || true
systemctl disable wg-quick@wg0 2>/dev/null || true

if ip link show wg0 >/dev/null 2>&1; then
    wg-quick down wg0 || true
    ip link delete wg0 || true
fi

rm -rf /etc/wireguard
rm -f /etc/sysctl.d/99-aegis-vpn.conf
sysctl --system >/dev/null || true

# iptables cleanup
iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null || true

INSTALL_DIR="$(dirname "$(realpath "$0")")"
rm -rf "$INSTALL_DIR"

echo "[*] Cleanup complete."
