#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Setup Script v1.3 (Security Update)
# Author: Rabindra
# Description: Automated WireGuard setup with IPv6,
#              hardened firewall, sysctl security, and
#              unattended install support.
# Usage: sudo ./setup.sh [--auto]
#===========================================================

set -e

# Vars
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
CLIENTS_DIR="$PWD/clients"
AUTO_MODE=false

if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

# Banner
if ! command -v figlet >/dev/null 2>&1; then
    apt-get update -qq && apt-get install -y figlet >/dev/null 2>&1
fi

clear
figlet -f big "AEGIS VPN"
echo -e "\e[1;32mSecure, Fast, Modern\e[0m"
echo -e "\e[1;33mby Rabindra - 2025\e[0m"
echo

SERVER_PUBLIC_IP=$(curl -s https://ipinfo.io/ip || echo "UNKNOWN")

echo "[*] Installing dependencies..."
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode nftables ufw

mkdir -p "$WG_DIR"

# v1.3 SYSTEM HARDENING
apply_sysctl_hardening() {
    echo "[*] Applying sysctl hardening..."
    cat <<EOF >/etc/sysctl.d/99-aegis-vpn.conf
# Aegis-VPN v1.3 sysctl hardening
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

    sysctl --system >/dev/null 2>&1
    echo "[+] sysctl hardened."
}

apply_firewall_hardening() {
    echo "[*] Applying firewall rules..."
    WG_PORT="${WG_PORT:-51820}"

    if command -v nft >/dev/null 2>&1; then
        nft list table inet filter >/dev/null 2>&1 || nft add table inet filter
        nft list chain inet filter input >/dev/null 2>&1 || nft add chain inet filter input { type filter hook input priority 0 \; }

        nft add rule inet filter input udp dport $WG_PORT limit rate 5/second burst 20 counter accept || true
        nft add rule inet filter input udp dport $WG_PORT counter drop || true
        nft add rule inet filter input ct state invalid drop || true

        echo "[+] nftables hardening applied."
    else
        ufw allow $WG_PORT/udp
        ufw limit $WG_PORT/udp
        ufw --force enable
        echo "[+] ufw fallback applied."
    fi
}

apply_sysctl_hardening
apply_firewall_hardening

# WireGuard Setup
echo "[*] Generating server keys..."
wg genkey | tee "$WG_DIR/privatekey" | wg pubkey > "$WG_DIR/publickey"
SERVER_PRIVATE_KEY=$(cat "$WG_DIR/privatekey")
SERVER_PUBLIC_KEY=$(cat "$WG_DIR/publickey")

echo "[*] Creating WireGuard config..."
cat > "$WG_DIR/$WG_INTERFACE.conf" <<EOF
[Interface]
Address = 10.10.0.1/24, fd00:10:10::1/64
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = false
MTU = 1280

PostUp   = nft add rule inet filter forward iifname "$WG_INTERFACE" accept; nft add rule inet filter forward oifname "$WG_INTERFACE" accept; nft add rule inet nat postrouting oifname "eth0" masquerade
PostDown = nft delete rule inet filter forward iifname "$WG_INTERFACE" accept; nft delete rule inet filter forward oifname "$WG_INTERFACE" accept; nft delete rule inet nat postrouting oifname "eth0" masquerade
EOF

chmod 600 "$WG_DIR/$WG_INTERFACE.conf"

echo "[*] Enabling WireGuard..."
systemctl enable wg-quick@$WG_INTERFACE
systemctl restart wg-quick@$WG_INTERFACE

echo
echo "====================================="
echo " Aegis-VPN Setup Complete (v1.3)"
echo "-------------------------------------"
echo " Server IP:       $SERVER_PUBLIC_IP"
echo " Server PubKey:   $SERVER_PUBLIC_KEY"
echo " Config:          $WG_DIR/$WG_INTERFACE.conf"
echo "====================================="
