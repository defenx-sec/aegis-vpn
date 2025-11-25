# Changelog

## v1.3 — 2025-11-15 (Security Update)
A focused security-hardening release with no breaking changes.

### 🔐 Firewall & Network Security
- Added rate-limiting for WireGuard UDP port (nftables-first, ufw fallback)
- Added invalid-packet dropping rules
- Improved forwarding and NAT cleanup logic

### 🛡 Sysctl Hardening
- Enforced IPv4/IPv6 redirect protections
- Disabled source routing and RA acceptance
- Ensured forwarding settings persist reliably

### ⚙ WireGuard Configuration
- Added MTU=1280 default to reduce fragmentation exposure
- Set `SaveConfig=false` for safer config management
- Updated server and client templates to match v1.3 security model

### 🧹 Cleanup Script Improvements
- Properly removes NAT rules (filter + nat tables)
- Removes stuck interfaces and leftover wg0 links
- Cleans up sysctl rules, ufw entries, old backups, and project directories

### 📱 Client Generation
- Added QR code fallback when `qrencode` is missing
- Added key-age warning logic

---
