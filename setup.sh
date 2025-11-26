#!/usr/bin/env bash
#===========================================================
# Aegis-VPN Setup Script v1.3 (Security Update - iptables)
# Author: Rabindra
# Description: Fully automated WireGuard setup with IPv6,
#              opinionated firewall hardening (iptables),
#              system tuning, and unattended install support.
# Usage: sudo ./setup.sh [--auto]
#===========================================================

set -euo pipefail

AUTO_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true

WG_INTERFACE="wg0"
WG_PORT="51820"
WG_DIR="/etc/wireguard"
CLIENTS_DIR="$(pwd)/clients"
SERVER_IPV4_CIDR="10.8.0.1/24"
SERVER_IPV4_ADDR="${SERVER_IPV4_CIDR%/*}"
SERVER_DNS="1.1.1.1"
SSH_PORT="${SSH_PORT:-22}"        # can be overridden via env
ALLOW_PING=true                   # set to false to block ICMP echo

# ---------- Helpers ----------

log()  { printf '[*] %s\n' "$*"; }
err()  { printf '[!] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "This script must be run as root (use sudo)."
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID=${ID:-unknown}
    else
        OS_ID=unknown
    fi

    case "$OS_ID" in
        ubuntu|debian) ;;
        *)
            err "Detected OS: $OS_ID"
            err "Script is tested only on Debian/Ubuntu. Proceed at your own risk."
        ;;
    esac
}

get_server_public_ip() {
    local ip
    ip=$(curl -4s https://ifconfig.co || curl -4s https://api.ipify.org || true)
    if [[ -z "$ip" ]]; then
        ip="0.0.0.0"
    fi
    SERVER_PUBLIC_IP="$ip"
}

prompt_if_needed() {
    if $AUTO_MODE; then
        return
    fi

    read -rp "WireGuard interface name [$WG_INTERFACE]: " tmp || true
    [[ -n "${tmp:-}" ]] && WG_INTERFACE="$tmp"

    read -rp "WireGuard UDP port [$WG_PORT]: " tmp || true
    [[ -n "${tmp:-}" ]] && WG_PORT="$tmp"

    read -rp "VPN IPv4 CIDR [$SERVER_IPV4_CIDR]: " tmp || true
    [[ -n "${tmp:-}" ]] && SERVER_IPV4_CIDR="$tmp" && SERVER_IPV4_ADDR="${SERVER_IPV4_CIDR%/*}"

    read -rp "DNS for clients [$SERVER_DNS]: " tmp || true
    [[ -n "${tmp:-}" ]] && SERVER_DNS="$tmp"

    read -rp "Server SSH port to keep open [$SSH_PORT]: " tmp || true
    [[ -n "${tmp:-}" ]] && SSH_PORT="$tmp"
}

ensure_dirs() {
    mkdir -p "$WG_DIR" "$CLIENTS_DIR" /var/log/aegis-vpn
    chmod 700 "$WG_DIR"
}

install_packages() {
    log "Updating apt and installing dependencies..."
    apt-get update -qq
    # qrencode is used for mobile configs; iptables-persistent to persist firewall
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        wireguard wireguard-tools qrencode \
        iptables iptables-persistent \
        curl >/dev/null
}

enable_ip_forwarding() {
    log "Enabling IP forwarding..."
    sed -i '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/^net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf

    {
        echo 'net.ipv4.ip_forward=1'
        echo 'net.ipv6.conf.all.forwarding=1'
    } >> /etc/sysctl.conf

    sysctl -p >/dev/null
}

generate_server_keys() {
    log "Generating WireGuard server keys..."
    umask 077
    wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
    wg genpsk > "$WG_DIR/server_preshared.key"
    SERVER_PRIVATE_KEY=$(<"$WG_DIR/server_private.key")
    SERVER_PUBLIC_KEY=$(<"$WG_DIR/server_public.key")
}

write_server_config() {
    log "Writing WireGuard server config at $WG_DIR/$WG_INTERFACE.conf..."

    cat > "$WG_DIR/$WG_INTERFACE.conf" <<EOF
[Interface]
Address = $SERVER_IPV4_CIDR
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIVATE_KEY
SaveConfig = true

# Log file (handled by systemd-journald usually)
# PostUp   = /usr/local/bin/aegis-vpn-log-hooks post-up
# PostDown = /usr/local/bin/aegis-vpn-log-hooks post-down
EOF

    chmod 600 "$WG_DIR/$WG_INTERFACE.conf"
}

detect_wan_interface() {
    # Best-effort detection of egress interface for NAT
    WAN_IF=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1); exit}')
    if [[ -z "${WAN_IF:-}" ]]; then
        WAN_IF=$(ip route | awk '/default/ {print $5; exit}')
    fi
    if [[ -z "${WAN_IF:-}" ]]; then
        die "Could not detect WAN interface (needed for iptables MASQUERADE)."
    fi
    log "Detected WAN interface: $WAN_IF"
}

apply_firewall_rules() {
    log "Applying hardened iptables firewall rules..."

    detect_wan_interface

    # Flush existing rules (assumes dedicated VPS)
    # IPv4 filter
    iptables -F
    iptables -X || true

    # IPv4 nat
    iptables -t nat -F
    iptables -t nat -X || true

    # IPv6 filter
    ip6tables -F
    ip6tables -X || true

    # Default policies: drop unsolicited inbound, allow outbound
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT ACCEPT

    # Allow loopback
    iptables  -A INPUT -i lo -j ACCEPT
    ip6tables -A INPUT -i lo -j ACCEPT

    # Allow established/related traffic
    iptables  -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow ICMP (ping) if enabled
    if $ALLOW_PING; then
        iptables  -A INPUT -p icmp -j ACCEPT
        ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
    fi

    # Allow SSH
    iptables  -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -j ACCEPT
    ip6tables -A INPUT -p tcp --dport "$SSH_PORT" -m conntrack --ctstate NEW -j ACCEPT

    # Allow WireGuard UDP
    iptables  -A INPUT -p udp --dport "$WG_PORT" -m conntrack --ctstate NEW -j ACCEPT
    ip6tables -A INPUT -p udp --dport "$WG_PORT" -m conntrack --ctstate NEW -j ACCEPT

    # Forwarding rules: VPN <-> WAN
    iptables -A FORWARD -i "$WG_INTERFACE" -o "$WAN_IF" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -i "$WAN_IF" -o "$WG_INTERFACE" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    ip6tables -A FORWARD -i "$WG_INTERFACE" -o "$WAN_IF" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A FORWARD -i "$WAN_IF" -o "$WG_INTERFACE" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # NAT for VPN clients (IPv4)
    iptables -t nat -A POSTROUTING -s "${SERVER_IPV4_CIDR}" -o "$WAN_IF" -j MASQUERADE

    # Persist rules
    log "Saving iptables rules (iptables-persistent)..."
    netfilter-persistent save >/dev/null 2>&1 || {
        # Fallback for older systems
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    }
}

start_wireguard() {
    log "Enabling and starting WireGuard..."
    systemctl enable "wg-quick@${WG_INTERFACE}"
    systemctl restart "wg-quick@${WG_INTERFACE}"
}

banner() {
    if command -v figlet >/dev/null 2>&1; then
        figlet "Aegis-VPN"
    else
        log "Aegis-VPN"
    fi
}

maybe_install_figlet() {
    if ! command -v figlet >/dev/null 2>&1; then
        log "Installing figlet for banner (optional)..."
        apt-get update -qq
        apt-get install -y figlet >/dev/null 2>&1 || true
    fi
}

# ---------- Main ----------

require_root
detect_os
maybe_install_figlet
banner
prompt_if_needed
ensure_dirs
install_packages
enable_ip_forwarding
get_server_public_ip
generate_server_keys
write_server_config
apply_firewall_rules
start_wireguard

log "WireGuard setup complete!"
log "Server Public IP: ${SERVER_PUBLIC_IP:-unknown}"
log "Config file location: $WG_DIR/$WG_INTERFACE.conf"
