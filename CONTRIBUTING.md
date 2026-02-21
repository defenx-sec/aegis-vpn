# Contributing to Aegis-VPN

Thank you for your interest in contributing to Aegis-VPN. Contributions of all kinds are welcome — bug fixes, new features, documentation improvements, and security reviews.

---

## Table of Contents

- [Reporting Issues](#reporting-issues)
- [Suggesting Features](#suggesting-features)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [License](#license)

---

## Reporting Issues

If you find a bug or unexpected behaviour:

1. Search [existing issues](https://github.com/defenx-sec/aegis-vpn/issues) first.
2. Open a new issue with:
   - **Title** — short, descriptive
   - **Description** — what happened vs. what you expected
   - **Steps to reproduce** — commands, scripts, config snippets
   - **Environment** — OS, WireGuard version, server type
3. Attach logs (`var/log/aegis-vpn/`) or `aegis-vpn check` output if relevant.

For security vulnerabilities, please open a private advisory rather than a public issue.

---

## Suggesting Features

Open an issue with:
- What the feature does and why it is useful
- Example use cases
- Optional: draft implementation idea or diagram

---

## Submitting Pull Requests

1. Fork the repository and clone your fork:
   ```bash
   git clone https://github.com/<your-username>/aegis-vpn.git
   cd aegis-vpn
   ```

2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. Make your changes (see [Coding Standards](#coding-standards) below).

4. Test on a clean environment (see [Testing](#testing)).

5. Commit with a clear message:
   ```bash
   git commit -m "feat: add X to improve client onboarding"
   ```

6. Push and open a PR against `main` on `defenx-sec/aegis-vpn`:
   - Describe what the PR does and why
   - Reference any related issues (e.g. `Closes #12`)
   - Include before/after output for CLI changes

> Do not push directly to `main`.

---

## Development Setup

```bash
# Install dependencies
sudo apt update
sudo apt install wireguard qrencode curl figlet bash coreutils

# Clone and set up
git clone https://github.com/<your-username>/aegis-vpn.git
cd aegis-vpn
sudo ./setup.sh --auto   # sets up WireGuard on the local machine

# Add a test client
sudo ./bin/aegis-vpn add

# Verify the CLI
sudo ./bin/aegis-vpn --help
sudo ./bin/aegis-vpn version
sudo ./bin/aegis-vpn check
```

---

## Coding Standards

All scripts must:

- Use `#!/usr/bin/env bash` as the shebang
- Include `set -euo pipefail`
- Source `scripts/lib.sh` for shared constants, colors, and helpers — do not re-declare path variables
- Quote all variables: `"$VAR"`, `"${ARRAY[@]}"`
- Use `print_ok`, `print_warn`, `print_err`, `print_info` from `lib.sh` for user-facing output
- Use `log_connection`, `log_error`, `log_audit` from `log_hooks.sh` for logging
- Pass a syntax check: `bash -n <script>`

Naming conventions:
- Scripts: `snake_case.sh`
- Constants: `UPPERCASE`
- Local variables: `lowercase`

Do not add hardcoded paths — use the variables exported by `lib.sh` (`BASE_DIR`, `CLIENTS_DIR`, `WG_DIR`, etc.).

---

## Testing

Before submitting:

1. Run syntax checks on all modified scripts:
   ```bash
   bash -n scripts/your_script.sh
   ```

2. Test end-to-end on a fresh system or VM:
   ```bash
   sudo ./setup.sh --auto
   sudo ./bin/aegis-vpn add
   sudo ./bin/aegis-vpn list
   sudo ./bin/aegis-vpn check
   sudo ./bin/aegis-vpn backup
   sudo ./bin/aegis-vpn remove
   ```

3. For key rotation changes:
   ```bash
   sudo ./bin/aegis-vpn rotate <client>
   sudo ./bin/aegis-vpn rotate-server
   sudo ./bin/aegis-vpn check
   ```

4. Verify WireGuard connectivity from a real client device.

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
