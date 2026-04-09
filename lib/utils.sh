#!/usr/bin/env bash
# lib/utils.sh — Guards, prompts, and utility functions

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root or with sudo."
    print_info "Try: sudo bash install.sh"
    exit 1
  fi
}

check_os() {
  if [ ! -f /etc/os-release ]; then
    print_error "Cannot detect OS. /etc/os-release not found."
    exit 1
  fi

  # shellcheck source=/dev/null
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VERSION_ID="${VERSION_ID:-0}"
  OS_CODENAME="${VERSION_CODENAME:-}"

  case "$OS_ID" in
    ubuntu|debian|raspbian) ;;
    *)
      print_error "Unsupported OS: ${OS_ID}."
      print_info "This script supports Ubuntu 20.04+, Debian 11+, and Raspbian."
      exit 1
      ;;
  esac

  if [ "$OS_ID" = "debian" ]; then
    MAJOR="${OS_VERSION_ID%%.*}"
    if [ "${MAJOR}" -lt 11 ] 2>/dev/null; then
      print_warn "Debian ${OS_VERSION_ID} is end-of-life. Issues may occur."
      confirm "Continue anyway?" || exit 0
    fi
  fi

  PKG_MANAGER="apt-get"
  export OS_ID OS_VERSION_ID OS_CODENAME PKG_MANAGER
}

check_arch() {
  local raw_arch
  raw_arch="$(uname -m)"

  case "$raw_arch" in
    x86_64)  CLOUDFLARED_ARCH="amd64" ;;
    aarch64) CLOUDFLARED_ARCH="arm64" ;;
    armv7l)  CLOUDFLARED_ARCH="armhf" ;;
    armv6l)  CLOUDFLARED_ARCH="arm" ;;
    *)
      print_error "Unsupported architecture: ${raw_arch}."
      print_info "Supported: x86_64, aarch64, armv7l, armv6l."
      exit 1
      ;;
  esac

  export CLOUDFLARED_ARCH
}

command_exists() {
  command -v "$1" &>/dev/null
}

# Wait until a local TCP port is listening
# Usage: wait_for_port <port> <timeout_seconds> <service_name>
wait_for_port() {
  local port="$1"
  local timeout="$2"
  local name="$3"
  local elapsed=0

  print_step "Waiting for ${name} to be ready on port ${port}..."

  while ! nc -z localhost "$port" 2>/dev/null; do
    sleep 2
    elapsed=$((elapsed + 2))
    printf "\r    ${DIM}Waiting... ${elapsed}s / ${timeout}s${RESET}"
    if [ "$elapsed" -ge "$timeout" ]; then
      printf "\n"
      print_error "${name} did not become ready within ${timeout}s."
      print_info "Check logs with: docker logs \$(docker ps -lq)"
      return 1
    fi
  done

  printf "\n"
  print_ok "${name} is ready."
}

# Prompt user for Y/n — default Y on Enter
# Usage: confirm "message"  →  returns 0 for yes, 1 for no
confirm() {
  local message="$1"
  local reply

  printf "${BOLD}%s${RESET} [Y/n]: " "$message"
  read -r reply </dev/tty
  reply="${reply:-Y}"

  case "$reply" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

prompt_panel_choice() {
  printf "\n${BOLD}Which panel would you like to install?${RESET}\n"
  printf "  1) Coolify   (port 8000)\n"
  printf "  2) EasyPanel (port 3000)\n\n"

  local choice
  while true; do
    printf "Enter choice [1-2]: "
    read -r choice </dev/tty
    case "$choice" in
      1)
        PANEL_CHOICE="coolify"
        PANEL_PORT=8000
        PANEL_NAME="Coolify"
        break
        ;;
      2)
        PANEL_CHOICE="easypanel"
        PANEL_PORT=3000
        PANEL_NAME="EasyPanel"
        break
        ;;
      *)
        print_warn "Invalid choice. Enter 1 or 2."
        ;;
    esac
  done

  export PANEL_CHOICE PANEL_PORT PANEL_NAME
}

prompt_domain_config() {
  printf "\n${BOLD}Domain Configuration${RESET}\n"
  printf "  ${DIM}You need a domain managed in Cloudflare.${RESET}\n\n"

  local domain_regex='^[a-zA-Z0-9][a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}$'

  while true; do
    printf "Base domain (e.g. example.com): "
    read -r BASE_DOMAIN </dev/tty
    if [[ "$BASE_DOMAIN" =~ $domain_regex ]]; then
      break
    else
      print_warn "Invalid domain format. Try again."
    fi
  done

  printf "Panel subdomain [cloud]: "
  read -r PANEL_SUBDOMAIN </dev/tty
  PANEL_SUBDOMAIN="${PANEL_SUBDOMAIN:-cloud}"

  printf "SSH subdomain [ssh]: "
  read -r SSH_SUBDOMAIN </dev/tty
  SSH_SUBDOMAIN="${SSH_SUBDOMAIN:-ssh}"

  printf "Tunnel name [home-server]: "
  read -r TUNNEL_NAME </dev/tty
  TUNNEL_NAME="${TUNNEL_NAME:-home-server}"

  PANEL_HOSTNAME="${PANEL_SUBDOMAIN}.${BASE_DOMAIN}"
  SSH_HOSTNAME="${SSH_SUBDOMAIN}.${BASE_DOMAIN}"

  export BASE_DOMAIN PANEL_SUBDOMAIN SSH_SUBDOMAIN TUNNEL_NAME PANEL_HOSTNAME SSH_HOSTNAME
}

confirm_summary() {
  printf "\n${BOLD}Installation Summary${RESET}\n"
  printf "  %-16s %s\n" "Panel:" "${PANEL_NAME} (port ${PANEL_PORT})"
  printf "  %-16s %s\n" "Panel URL:" "https://${PANEL_HOSTNAME}"
  printf "  %-16s %s\n" "SSH access:" "${SSH_HOSTNAME}"
  printf "  %-16s %s\n" "Tunnel name:" "${TUNNEL_NAME}"
  printf "\n"

  confirm "Proceed with installation?" || {
    print_info "Installation cancelled."
    exit 0
  }
  printf "\n"
}

check_port_free() {
  local port="$1"
  if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
    print_warn "Port ${port} is already in use."
    confirm "Something may already be running. Continue anyway?" || exit 0
  fi
}
