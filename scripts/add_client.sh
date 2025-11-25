#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Client Generator v1.3 (iptables mode)
#===========================================================

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLIENTS_DIR="$BASE_DIR/clients"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

mkdir -p "$CLIENTS_DIR"

CLIENT_NAME="$1"
if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: sudo ./add_client.sh <client-name>"
    exit 1
fi

SERVER_PUBLIC_KEY=$(cat "$WG_DIR/publickey")
SERVER_IP=$(curl -s https://ipinfo.io/ip || echo "0.0.0.0")

NEXT_ID=$(( $(ls "$CLIENTS_DIR" | grep -c '.conf$') + 2 ))
CLIENT_IPv4="10.10.0.$NEXT_ID"
CLIENT_IPv6="fd00:10:10::$NEXT_ID"

CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

CLIENT_CONF="$CLIENTS_DIR/$CLIENT_NAME.conf"

cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IPv4/32, $CLIENT_IPv6/128
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"

# Add peer to server config
cat >> "$WG_DIR/$WG_INTERFACE.conf" <<EOF

# $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IPv4/32,$CLIENT_IPv6/128
EOF

wg set "$WG_INTERFACE" peer "$CLIENT_PUBLIC_KEY" allowed-ips "$CLIENT_IPv4/32,$CLIENT_IPv6/128"

echo "[*] QR Code:"
if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ansiutf8 < "$CLIENT_CONF"
else
    cat "$CLIENT_CONF"
fi

echo "[+] Client added: $CLIENT_NAME"
echo "Config: $CLIENT_CONF"
