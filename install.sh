#!/usr/bin/env bash
# local-vps install.sh — Home server setup: Cloudflare Tunnel + Coolify/EasyPanel
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USER/local-vps/main/install.sh | bash
#   -or-
#   git clone https://github.com/YOUR_USER/local-vps && cd local-vps && sudo bash install.sh

set -euo pipefail

# ── curl | bash bootstrap ────────────────────────────────────────────────────
# When piped through bash, BASH_SOURCE[0] is "bash" or empty.
# We download the repo to a temp dir and re-execute from disk so lib files exist.
if [[ "${BASH_SOURCE[0]:-bash}" == "bash" ]]; then
  INSTALL_DIR="/tmp/local-vps-$$"
  echo "[→] Downloading local-vps to ${INSTALL_DIR}..."

  if command -v git &>/dev/null; then
    git clone --depth=1 https://github.com/YOUR_USER/local-vps "$INSTALL_DIR" 2>/dev/null
  else
    mkdir -p "$INSTALL_DIR"
    curl -fsSL https://github.com/YOUR_USER/local-vps/archive/main.tar.gz \
      | tar -xz -C /tmp
    mv /tmp/local-vps-main "$INSTALL_DIR" 2>/dev/null \
      || mv /tmp/local-vps-main/* "$INSTALL_DIR"/ 2>/dev/null || true
  fi

  exec bash "$INSTALL_DIR/install.sh" "$@"
fi

# ── Resolve script directory (works with symlinks) ───────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Source lib files ──────────────────────────────────────────────────────────
# shellcheck source=lib/colors.sh
source "${SCRIPT_DIR}/lib/colors.sh"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/lib/utils.sh"
# shellcheck source=lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=lib/coolify.sh
source "${SCRIPT_DIR}/lib/coolify.sh"
# shellcheck source=lib/easypanel.sh
source "${SCRIPT_DIR}/lib/easypanel.sh"
# shellcheck source=lib/cloudflare.sh
source "${SCRIPT_DIR}/lib/cloudflare.sh"

# ── Error & interrupt traps ───────────────────────────────────────────────────
trap 'print_error "Fatal error on line ${LINENO}. Exit code: $?"' ERR
trap 'printf "\n"; print_warn "Installation interrupted. It is safe to re-run this script."; exit 130' INT TERM

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  show_banner

  # System checks
  check_root
  check_os
  check_arch

  # Interactive prompts
  prompt_panel_choice
  prompt_domain_config
  confirm_summary

  # Install panel
  install_docker

  if [ "$PANEL_CHOICE" = "coolify" ]; then
    install_coolify
  else
    install_easypanel
  fi

  # Set up Cloudflare tunnel
  setup_tunnel

  # Completion
  show_completion_summary
}

show_completion_summary() {
  local info_file="/root/local-vps-setup-info.txt"

  local ssh_block
  ssh_block="$(cat <<EOF

Host ${SSH_HOSTNAME}
  ProxyCommand cloudflared access ssh --hostname %h

EOF
)"

  local summary
  summary="$(cat <<EOF

════════════════════════════════════════════════════════
  Setup Complete!
════════════════════════════════════════════════════════

  Panel:    https://${PANEL_HOSTNAME}
            (DNS may take 1-2 minutes to propagate)

  ── SSH Client Setup (run on YOUR LOCAL machine) ──

  1. Install cloudflared locally:
       macOS:   brew install cloudflared
       Windows: winget install Cloudflare.cloudflared
       Linux:   https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/

  2. Add to ~/.ssh/config on your local machine:
${ssh_block}
  3. Connect:
       ssh root@${SSH_HOSTNAME}

     Note: First connection will open a browser for
     Cloudflare authentication, then works transparently.

════════════════════════════════════════════════════════

  This info has been saved to: ${info_file}

EOF
)"

  printf "%s\n" "$summary"

  # Save to file for later reference
  printf "%s\n" "$summary" > "$info_file"
  print_info "Setup info saved to ${info_file}"
}

main "$@"
