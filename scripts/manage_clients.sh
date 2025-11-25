#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Client Manager v1.3
#===========================================================

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENTS_DIR="$BASE_DIR/clients"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

mkdir -p "$CLIENTS_DIR"

add_client() {
    CLIENT_NAME="$1"
    [ -z "$CLIENT_NAME" ] && read -p "Enter client name: " CLIENT_NAME
    sudo "$BASE_DIR/scripts/add_client.sh" "$CLIENT_NAME"
}

remove_client() {
    CLIENT_NAME="$1"
    [ -z "$CLIENT_NAME" ] && read -p "Enter client name: " CLIENT_NAME

    CONF="$CLIENTS_DIR/$CLIENT_NAME.conf"
    if [ ! -f "$CONF" ]; then
        echo "[!] Client does not exist."
        return 1
    fi

    PUBLIC_KEY=$(grep -A2 "# $CLIENT_NAME" "$WG_DIR/$WG_INTERFACE.conf" | grep PublicKey | awk '{print $3}')

    rm -f "$CONF"

    if [ -n "$PUBLIC_KEY" ]; then
        wg set "$WG_INTERFACE" peer "$PUBLIC_KEY" remove || true
    fi

    sed -i "/# $CLIENT_NAME/,+3d" "$WG_DIR/$WG_INTERFACE.conf"

    echo "[+] Client removed: $CLIENT_NAME"
}

list_clients() {
    echo "[*] Clients:"
    ls "$CLIENTS_DIR" | grep ".conf$" || echo "No clients."
}

monitor_clients() {
    echo "[*] Active peers:"
    wg show "$WG_INTERFACE" latest-handshakes
}

case "$1" in
    add) add_client "$2" ;;
    remove) remove_client "$2" ;;
    list) list_clients ;;
    monitor) monitor_clients ;;
    *)
        echo "Usage: manage_clients.sh [add|remove|list|monitor]"
        ;;
esac
