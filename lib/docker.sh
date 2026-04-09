#!/usr/bin/env bash
# lib/docker.sh — Docker CE installation

install_docker() {
  if command_exists docker; then
    print_ok "Docker already installed ($(docker --version 2>/dev/null | head -1))"
    return 0
  fi

  print_step "Installing Docker CE..."

  # Remove conflicting packages
  $PKG_MANAGER remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

  # Install via official convenience script
  curl -fsSL https://get.docker.com | sh

  # Start and enable
  systemctl enable --now docker

  # Verify
  if docker run --rm hello-world &>/dev/null; then
    print_ok "Docker CE installed successfully."
  else
    print_warn "Docker installed but hello-world test failed. Continuing anyway."
  fi
}
