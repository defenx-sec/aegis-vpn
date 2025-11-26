#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Cleanup Script v1.3
# Author: Rabindra
# Description: Completely removes Aegis-VPN setup, configs,
#              logs, firewall rules, and WireGuard.
# Usage: sudo ./cleanup.sh
#===========================================================

set -euo pipefail

log()  { printf '[*] %s\n' "$*"; }
err()  { printf '[!] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "This script must be run as root (use sudo)."
    fi
}

wipe_firewall_rules() {
    log "Reverting iptables firewall rules..."

    # IPv4 filter
    iptables -P INPUT ACCEPT || true
    iptables -P FORWARD ACCEPT || true
    iptables -P OUTPUT ACCEPT || true
    iptables -F || true
    iptables -X || true

    # IPv4 nat
    iptables -t nat -F || true
    iptables -t nat -X || true

    # IPv6 filter
    ip6tables -P INPUT ACCEPT || true
    ip6tables -P FORWARD ACCEPT || true
    ip6tables -P OUTPUT ACCEPT || true
    ip6tables -F || true
    ip6tables -X || true

    # IPv6 nat (not always present)
    ip6tables -t nat -F 2>/dev/null || true
    ip6tables -t nat -X 2>/dev/null || true

    # Try to clear persisted rules
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    else
        rm -f /etc/iptables/rules.v4 /etc/iptables/rules.v6 2>/dev/null || true
    fi
}

main() {
    require_root()

    echo "[*] WARNING: This will remove all Aegis-VPN files and configurations."
    read -rp "Do you really want to continue? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "[*] Cleanup aborted."
        exit 0
    fi

    systemctl stop "wg-quick@wg0" 2>/dev/null || true
    systemctl disable "wg-quick@wg0" 2>/dev/null || true

    log "Removing WireGuard configs and keys..."
    rm -rf /etc/wireguard
    rm -rf /var/log/aegis-vpn
    rm -rf "$(pwd)/clients"

    wipe_firewall_rules

    read -rp "Do you want to remove WireGuard and dependencies? (y/N): " dep_confirm
    if [[ "$dep_confirm" == "y" || "$dep_confirm" == "Y" ]]; then
        log "Removing WireGuard and related packages..."
        apt-get remove --purge -y wireguard wireguard-tools qrencode iptables-persistent netfilter-persistent || true
        apt-get autoremove -y || true
    fi

    log "Cleanup complete! All Aegis-VPN files and firewall rules have been removed."
}

main "$@"
