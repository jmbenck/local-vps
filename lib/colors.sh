#!/usr/bin/env bash
# lib/colors.sh — Terminal colors and print helpers

# Detect color support
if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM}" != "dumb" ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
fi

print_step() {
  printf "${CYAN}${BOLD}[→]${RESET} %s\n" "$1"
}

print_ok() {
  printf "${GREEN}${BOLD}[✓]${RESET} %s\n" "$1"
}

print_warn() {
  printf "${YELLOW}${BOLD}[!]${RESET} %s\n" "$1"
}

print_error() {
  printf "${RED}${BOLD}[✗]${RESET} %s\n" "$1" >&2
}

print_info() {
  printf "    ${DIM}%s${RESET}\n" "$1"
}

show_banner() {
  printf "\n${BOLD}${BLUE}"
  printf '  _                    _   __   ______  _____  \n'
  printf ' | |                  | | |  | | |  \ \/ __  \ \n'
  printf ' | |     ___   ___ __ | | |  | | |__) | (___) |\n'
  printf ' | |    / _ \ / __|  \| |  \ | |  ___/ \___  / \n'
  printf ' | |___| (_) | (__| () | |__| | | |    ___) |  \n'
  printf ' |______\___/ \___|____/|____/ |_|   |_____/   \n'
  printf "${RESET}\n"
  printf "  ${DIM}Home Server Setup — Cloudflare Tunnel + Panel${RESET}\n\n"
}
