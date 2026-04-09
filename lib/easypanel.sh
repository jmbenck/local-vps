#!/usr/bin/env bash
# lib/easypanel.sh — EasyPanel installation

install_easypanel() {
  # Check if already running
  if docker ps --filter name=easypanel --format '{{.Names}}' 2>/dev/null | grep -q easypanel; then
    print_warn "EasyPanel appears to already be running."
    confirm "Skip EasyPanel installation?" && return 0
  fi

  check_port_free "$PANEL_PORT"

  print_step "Installing EasyPanel..."
  curl -sSL https://get.easypanel.io | sh

  wait_for_port "$PANEL_PORT" 180 "EasyPanel" || {
    print_error "EasyPanel did not start in time. Check: docker logs easypanel"
    exit 1
  }

  print_ok "EasyPanel is running at http://localhost:${PANEL_PORT}"
}
