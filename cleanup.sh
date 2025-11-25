#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Cleanup Script v1.3
# Author: Rabindra
# Description: Clean removal of WireGuard, configs, logs,
#              firewall rules, sysctl hardening, and scripts.
# Usage: sudo ./cleanup.sh
#===========================================================

set -e

echo "[*] WARNING: This will remove ALL Aegis-VPN data, configs, and rules."
read -p "Continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "[*] Cleanup aborted."
    exit 0
fi

# STOP & DISABLE WIREGUARD
echo "[*] Stopping WireGuard..."
systemctl stop wg-quick@wg0 2>/dev/null || true
systemctl disable wg-quick@wg0 2>/dev/null || true
systemctl daemon-reload

# Kill any stuck interface
if ip link show wg0 >/dev/null 2>&1; then
    wg-quick down wg0 2>/dev/null || true
    ip link delete wg0 2>/dev/null || true
fi

# REMOVE WIREGUARD CONFIGS
echo "[*] Removing WireGuard configs..."
rm -rf /etc/wireguard 2>/dev/null || true

# Remove systemd override files, if any
rm -rf /etc/systemd/system/wg-quick@wg0.service.d 2>/dev/null || true

# REMOVE PROJECT FILES
echo "[*] Removing Aegis-VPN project files..."

# automatically detect install directory
INSTALL_DIR="$(dirname "$(realpath "$0")")"
PROJECT_ROOT="$(dirname "$INSTALL_DIR")"

rm -rf "$PROJECT_ROOT" 2>/dev/null || true

# also clean backups
find / -type f -name "*.bak_v1.3" -delete 2>/dev/null || true

# FIREWALL CLEANUP (UFW + NFT)
echo "[*] Cleaning firewall rules..."

# UFW
if command -v ufw >/dev/null 2>&1; then
    ufw delete allow 51820/udp 2>/dev/null || true
    ufw reload 2>/dev/null || true
fi

# iptables fallback
iptables -F || true
ip6tables -F || true

# nftables cleanup
if command -v nft >/dev/null 2>&1; then
    nft flush table inet filter 2>/dev/null || true
    nft flush table inet nat 2>/dev/null || true
fi

# REMOVE SYSCTL HARDENING
if [ -f /etc/sysctl.d/99-aegis-vpn.conf ]; then
    echo "[*] Removing sysctl hardening..."
    rm -f /etc/sysctl.d/99-aegis-vpn.conf
    sysctl --system >/dev/null 2>&1 || true
fi

# OPTIONAL: REMOVE PACKAGES
read -p "Remove WireGuard + dependencies? (y/N): " dep_confirm
if [[ "$dep_confirm" == "y" || "$dep_confirm" == "Y" ]]; then
    echo "[*] Removing packages..."
    apt-get remove --purge -y wireguard wireguard-tools qrencode ufw || true
    apt-get autoremove -y || true
fi

echo
echo "[+] Cleanup complete — Aegis-VPN has been fully removed."
