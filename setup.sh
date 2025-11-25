#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Setup Script v1.3 (Security Update - iptables FIXED)
# Author: Rabindra
#===========================================================

set -e

WG_INTERFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
CLIENTS_DIR="$PWD/clients"

# Detect outbound interface dynamically
OUT_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')

echo "[*] Detected outbound interface: $OUT_IFACE"

# Cleanup old configs to avoid conflicts
rm -f /etc/wireguard/wg0.conf

# Install dependencies
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode iptables-persistent

# SYSCTL HARDENING
cat <<EOF >/etc/sysctl.d/99-aegis-vpn.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
EOF

sysctl --system >/dev/null

# FIREWALL RULES
iptables -t nat -A POSTROUTING -o $OUT_IFACE -j MASQUERADE
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# Generate keys
mkdir -p $WG_DIR
wg genkey | tee $WG_DIR/privatekey | wg pubkey > $WG_DIR/publickey
SERVER_PRIVATE_KEY=$(cat $WG_DIR/privatekey)

# Create wg0.conf
cat > $WG_DIR/wg0.conf <<EOF
[Interface]
Address = 10.10.0.1/24, fd00:10:10::1/64
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = false
MTU = 1280

PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $OUT_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $OUT_IFACE -j MASQUERADE
EOF

chmod 600 $WG_DIR/wg0.conf

# Restart WG
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo
echo "====================================="
echo " Aegis-VPN Setup Complete (v1.3)"
echo "-------------------------------------"
echo " Server IP:       $SERVER_PUBLIC_IP"
echo " Server PubKey:   $SERVER_PUBLIC_KEY"
echo " Config:          $WG_DIR/$WG_INTERFACE.conf"
echo "====================================="
