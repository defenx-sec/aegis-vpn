#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Client Manager v1.3
# Author: Rabindra
#===========================================================

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
CLIENTS_DIR="$BASE_DIR/clients"
WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"

KEY_AGE_THRESHOLD_DAYS=90

source "$SCRIPTS_DIR/log_hooks.sh"

mkdir -p "$CLIENTS_DIR"

check_key_age() {
    local keyfile="$1"
    if [ ! -f "$keyfile" ]; then return; fi

    key_mtime=$(stat -c %Y "$keyfile")
    now_ts=$(date +%s)
    age_days=$(( (now_ts - key_mtime) / 86400 ))

    if [ "$age_days" -ge "$KEY_AGE_THRESHOLD_DAYS" ]; then
        echo "[!] Key $keyfile is ${age_days}d old — rotation recommended."
    fi
}

remove_client() {
    CLIENT_NAME="$1"

    if [ -z "$CLIENT_NAME" ]; then
        read -p "Enter client name: " CLIENT_NAME
    fi

    CONF="$CLIENTS_DIR/$CLIENT_NAME.conf"
    if [ ! -f "$CONF" ]; then
        echo "[!] Client does not exist."
        log_error "remove failed: $CLIENT_NAME not found"
        return 1
    fi

    PUBLIC_KEY=$(grep -A 4 "\[$CLIENT_NAME\]" "$WG_DIR/$WG_INTERFACE.conf" 2>/dev/null | grep PublicKey | awk '{print $3}')

    rm -f "$CONF"

    if [ -n "$PUBLIC_KEY" ]; then
        wg set "$WG_INTERFACE" peer "$PUBLIC_KEY" remove || true
    fi

    sed -i "/# $CLIENT_NAME/,+3d" "$WG_DIR/$WG_INTERFACE.conf"

    log_connection "$CLIENT_NAME" "N/A" "disconnected"
    log_audit "Client removed: $CLIENT_NAME"

    echo "[+] Client removed: $CLIENT_NAME"
}

list_clients() {
    echo "[*] Clients:"
    ls "$CLIENTS_DIR" | grep ".conf$" || echo "No clients."
}

monitor_clients() {
    echo "[*] Monitoring active peers..."
    wg show "$WG_INTERFACE" latest-handshakes || echo "wg0 not running."
}

ACTION="$1"

case "$ACTION" in
    add) "$SCRIPTS_DIR/add_client.sh" "$2" ;;
    remove) remove_client "$2" ;;
    list) list_clients ;;
    monitor) monitor_clients ;;
    *)
        echo "Usage: manage_clients.sh [add|remove|list|monitor]"
        ;;
esac
