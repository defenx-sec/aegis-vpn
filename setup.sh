#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Setup Script v1.3 (Security Update - iptables)
# Author: Rabindra
#===========================================================

set -e

WG_INTERFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
CLIENTS_DIR="$PWD/clients"

AUTO_MODE=false
[[ "$1" == "--auto" ]] && AUTO_MODE=true

# Install banner tool
if ! command -v figlet >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y figlet >/dev/null 2>&1
fi

clear
figlet -f big "AEGIS VPN"
echo -e "\e[1;32mSecure, Fast, Modern\e[0m"
echo -e "\e[1;33mby Rabindra - 2025\e[0m"
echo

SERVER_PUBLIC_IP=$(curl -s https://ipinfo.io/ip || echo "UNKNOWN")

echo "[*] Installing dependencies..."
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode ufw

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

# iptables FIREWALL HARDENING
apply_firewall_hardening() {
    echo "[*] Applying iptables firewall rules..."

    # NAT for IPv4
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

    # Forwarding rules
    iptables -A FORWARD -i wg0 -j ACCEPT
    iptables -A FORWARD -o wg0 -j ACCEPT

    # Rate-limit WG port
    iptables -A INPUT -p udp --dport $WG_PORT -m limit --limit 5/second --limit-burst 20 -j ACCEPT
    iptables -A INPUT -p udp --dport $WG_PORT -j DROP

    echo "[+] iptables firewall hardened."
}

apply_sysctl_hardening
apply_firewall_hardening

# WireGuard Setup
echo "[*] Generating server keys..."
wg genkey | tee "$WG_DIR/privatekey" | wg pubkey > "$WG_DIR/publickey"

SERVER_PRIVATE_KEY=$(cat "$WG_DIR/privatekey")
SERVER_PUBLIC_KEY=$(cat "$WG_DIR/publickey")

echo "[*] Creating WireGuard server config..."
cat > "$WG_DIR/$WG_INTERFACE.conf" <<EOF
[Interface]
Address = 10.10.0.1/24, fd00:10:10::1/64
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = false
MTU = 1280

# iptables NAT & forwarding
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

chmod 600 "$WG_DIR/$WG_INTERFACE.conf"

echo "[*] Starting WireGuard..."
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
