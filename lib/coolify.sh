#!/usr/bin/env bash
# lib/coolify.sh — Coolify installation

install_coolify() {
  # Check if already running
  if docker ps --filter name=coolify --format '{{.Names}}' 2>/dev/null | grep -q coolify; then
    print_warn "Coolify appears to already be running."
    confirm "Skip Coolify installation?" && return 0
  fi

  check_port_free "$PANEL_PORT"

  print_step "Installing Coolify..."
  curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

  wait_for_port "$PANEL_PORT" 180 "Coolify" || {
    print_error "Coolify did not start in time. Check: docker logs coolify"
    exit 1
  }

  print_ok "Coolify is running at http://localhost:${PANEL_PORT}"
}
