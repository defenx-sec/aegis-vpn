#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Setup Script (Germany Server) v1.1
# Author: Rabindra
# Description: Fully automated WireGuard setup with IPv6,
#              firewall hardening, system tuning, and
#              unattended install support.
# Usage: sudo ./setup.sh [--auto]
#===========================================================

# Install figlet if missing (quietly)
if ! command -v figlet >/dev/null 2>&1; then
    echo "[*] Installing figlet for banner..."
    sudo apt-get update -qq
    sudo apt-get install -y figlet >/dev/null 2>&1
fi

# Display banner
clear
figlet -f big "AEGIS VPN"
echo -e "\e[1;32mSecure, Fast, Modern\e[0m"
echo -e "\e[1;33mby Rabindra - 2025\e[0m"
echo

set -e 

# Variables
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
CLIENTS_DIR="$PWD/clients"
AUTO_MODE=false

# Detect auto mode
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

# Get public IP
SERVER_PUBLIC_IP=$(curl -s https://ipinfo.io/ip)

# Install Dependencies
echo "[*] Installing dependencies..."
apt-get update
apt-get install -y wireguard qrencode ufw

# Enable IP forwarding
echo "[*] Enabling IPv4 and IPv6 forwarding..."
SYSCTL_FILE="/etc/systl.conf"
# Create sysctl.conf if it doesn't exist
if [ ! -f "$SYSCTL_FILE" ]; then
    echo "[*] /etc/sysctl.conf not found. Creating..."
    touch "$SYSCTL_FILE"
fi

sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

sed -i '/^net.ipv4.ip_forward/d' "$SYSCTL_FILE"
echo "net.ipv4.ip_forward=1" >> "$SYSCTL_FILE"

sed -i '/^net.ipv6.conf.all.forwarding/d' "$SYSCTL_FILE"
echo "net.ipv6.conf.all.forwarding=1" >> "$SYSCTL_FILE"

# Generate server keys
echo "[*] Generating server keys..."
mkdir -p $WG_DIR
cd $WG_DIR
wg genkey | tee privatekey | wg pubkey > publickey
SERVER_PRIVATE_KEY=$(cat privatekey)
SERVER_PUBLIC_KEY=$(cat publickey)

# Create wg0.conf
echo "[*] Creating $WG_INTERFACE.conf"
cat > $WG_INTERFACE.conf <<EOF
[Interface]
Address = 10.10.0.1/24, fd86:ea04:1115::1/64
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = true
PostUp = ufw route allow in on $WG_INTERFACE out on enX0; ufw route allow in on enX0 out on $WG_INTERFACE
PostDown = ufw route delete allow in on $WG_INTERFACE out on enX0; ufw route delete allow in on enX0 out on $WG_INTERFACE
EOF


chmod 600 $WG_INTERFACE.conf

# Start & Enable WireGuard
echo "[*] Starting WireGuard..."
systemctl enable wg-quick@$WG_INTERFACE
systemctl start wg-quick@$WG_INTERFACE

# Firewall
echo "[*] Applying basic firewall rules..."
ufw allow $WG_PORT/udp
ufw --force enable

echo "[*] WireGuard setup complete!"
echo "Server Public IP: $SERVER_PUBLIC_IP"
echo "Config file location: $WG_DIR/$WG_INTERFACE.conf"
