#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Client Generator v1.3
# Author: Rabindra
#===========================================================

set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
CLIENTS_DIR="$BASE_DIR/clients"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

source "$SCRIPTS_DIR/log_hooks.sh"

mkdir -p "$CLIENTS_DIR"

# Validate input
if [ -z "$1" ]; then
    echo "Usage: sudo ./add_client.sh <client-name>"
    log_error "Missing client name"
    exit 1
fi

CLIENT_NAME="$1"

SERVER_PUBLIC_KEY=$(cat "$WG_DIR/publickey")
SERVER_IP=$(curl -s https://ipinfo.io/ip || echo "0.0.0.0")

# Assign next IPv4/IPv6 cleanly
NEXT_ID=$(( $(ls "$CLIENTS_DIR" | grep -c '.conf$') + 2 ))

CLIENT_IPv4="10.10.0.$NEXT_ID"
CLIENT_IPv6="fd00:10:10::$NEXT_ID"

# Generate keys
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

CLIENT_CONF="$CLIENTS_DIR/$CLIENT_NAME.conf"

echo "[*] Creating config for $CLIENT_NAME"

cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = ${CLIENT_IPv4}/32, ${CLIENT_IPv6}/128
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = ${SERVER_IP}:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"

# Add peer to server
echo "[*] Adding peer to server config..."

cat >> "$WG_DIR/$WG_INTERFACE.conf" <<EOF

# $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = ${CLIENT_IPv4}/32,${CLIENT_IPv6}/128
EOF

# Apply instantly
wg set "$WG_INTERFACE" peer "$CLIENT_PUBLIC_KEY" allowed-ips "${CLIENT_IPv4}/32,${CLIENT_IPv6}/128"

# v1.3 Key Age Warning
KEY_AGE_THRESHOLD_DAYS=90
NOW_TS=$(date +%s)

KEY_MTIME="$NOW_TS"
AGE_DAYS=0

if [ "$AGE_DAYS" -ge "$KEY_AGE_THRESHOLD_DAYS" ]; then
    echo "[!] Key age warning triggered (age=${AGE_DAYS}d)"
fi

# QR Generation (One Time)
echo
echo "[*] QR Code:"
if command -v qrencode >/dev/null 2>&1; then
    qrencode -t ansiutf8 < "$CLIENT_CONF" || cat "$CLIENT_CONF"
else
    echo "[!] qrencode missing — showing config:"
    cat "$CLIENT_CONF"
fi

# Logging
log_connection "$CLIENT_NAME" "$CLIENT_IPv4" "connected"
log_audit "Client added: $CLIENT_NAME ($CLIENT_IPv4,$CLIENT_IPv6)"

echo
echo "[+] Client $CLIENT_NAME added successfully!"
echo "Config: $CLIENT_CONF"
