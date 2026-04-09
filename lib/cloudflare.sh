#!/usr/bin/env bash
# lib/cloudflare.sh — Cloudflare Tunnel setup

CLOUDFLARED_CONFIG_DIR="/root/.cloudflared"

install_cloudflared() {
  if command_exists cloudflared; then
    print_ok "cloudflared already installed ($(cloudflared --version 2>&1 | head -1))"
    return 0
  fi

  check_arch

  print_step "Installing cloudflared (${CLOUDFLARED_ARCH})..."

  local deb_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}.deb"
  local tmp_deb="/tmp/cloudflared-$$.deb"

  curl -fsSL "$deb_url" -o "$tmp_deb"
  dpkg -i "$tmp_deb"
  rm -f "$tmp_deb"

  cloudflared --version &>/dev/null || {
    print_error "cloudflared installation failed."
    exit 1
  }

  print_ok "cloudflared installed."
}

cloudflared_login() {
  if [ -f "${CLOUDFLARED_CONFIG_DIR}/cert.pem" ]; then
    print_ok "Cloudflare credentials already present. Skipping login."
    return 0
  fi

  print_step "Authenticating with Cloudflare..."
  printf "\n"
  print_info "A URL will be shown below (or a browser may open)."
  print_info "Log in and authorize the domain: ${BASE_DOMAIN}"
  print_info "The script will continue automatically after you authorize."
  printf "\n"

  cloudflared tunnel login

  if [ ! -f "${CLOUDFLARED_CONFIG_DIR}/cert.pem" ]; then
    print_error "Authentication failed. cert.pem not found."
    exit 1
  fi

  print_ok "Cloudflare authentication successful."
}

create_tunnel() {
  print_step "Setting up tunnel: ${TUNNEL_NAME}..."

  # Check if tunnel already exists
  local existing_id
  existing_id=$(cloudflared tunnel list 2>/dev/null \
    | awk -v name="$TUNNEL_NAME" '$2 == name { print $1 }' \
    | head -1)

  if [ -n "$existing_id" ]; then
    TUNNEL_ID="$existing_id"
    print_warn "Tunnel '${TUNNEL_NAME}' already exists (ID: ${TUNNEL_ID})"
    confirm "Use existing tunnel?" || exit 1
  else
    # Snapshot credentials files before creation
    local before after new_creds
    before=$(ls "${CLOUDFLARED_CONFIG_DIR}"/*.json 2>/dev/null | sort || true)

    cloudflared tunnel create "${TUNNEL_NAME}"

    after=$(ls "${CLOUDFLARED_CONFIG_DIR}"/*.json 2>/dev/null | sort || true)
    new_creds=$(comm -13 <(echo "$before") <(echo "$after") | head -1)

    if [ -z "$new_creds" ]; then
      print_error "Could not find credentials file after tunnel creation."
      exit 1
    fi

    TUNNEL_ID=$(basename "$new_creds" .json)
    print_ok "Tunnel created. ID: ${TUNNEL_ID}"
  fi

  # Validate UUID format
  if ! [[ "$TUNNEL_ID" =~ ^[0-9a-f-]{36}$ ]]; then
    print_error "Unexpected tunnel ID format: '${TUNNEL_ID}'"
    exit 1
  fi

  export TUNNEL_ID
}

generate_config() {
  local config_file="${CLOUDFLARED_CONFIG_DIR}/config.yml"

  # Backup existing config
  if [ -f "$config_file" ]; then
    cp "$config_file" "${config_file}.bak.$(date +%s)"
    print_info "Backed up existing config.yml"
  fi

  print_step "Writing tunnel configuration..."

  mkdir -p "$CLOUDFLARED_CONFIG_DIR"

  cat > "$config_file" <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: ${CLOUDFLARED_CONFIG_DIR}/${TUNNEL_ID}.json

ingress:
  - hostname: ${PANEL_HOSTNAME}
    service: http://localhost:${PANEL_PORT}
  - hostname: ${SSH_HOSTNAME}
    service: ssh://localhost:22
  - service: http_status:404
EOF

  print_ok "Config written to ${config_file}"
}

route_dns() {
  print_step "Creating Cloudflare DNS records..."

  local dns_out

  # Panel hostname
  dns_out=$(cloudflared tunnel route dns "${TUNNEL_NAME}" "${PANEL_HOSTNAME}" 2>&1) || {
    if echo "$dns_out" | grep -qi "already exists\|already routed"; then
      print_warn "DNS record for ${PANEL_HOSTNAME} already exists."
    else
      print_error "Failed to create DNS record for ${PANEL_HOSTNAME}:"
      print_info "$dns_out"
      exit 1
    fi
  }
  print_ok "DNS: ${PANEL_HOSTNAME} → tunnel"

  # SSH hostname
  dns_out=$(cloudflared tunnel route dns "${TUNNEL_NAME}" "${SSH_HOSTNAME}" 2>&1) || {
    if echo "$dns_out" | grep -qi "already exists\|already routed"; then
      print_warn "DNS record for ${SSH_HOSTNAME} already exists."
    else
      print_error "Failed to create DNS record for ${SSH_HOSTNAME}:"
      print_info "$dns_out"
      exit 1
    fi
  }
  print_ok "DNS: ${SSH_HOSTNAME} → tunnel"
}

install_tunnel_service() {
  print_step "Installing cloudflared as a systemd service..."

  # Remove existing service if present (re-run scenario)
  if systemctl is-active --quiet cloudflared 2>/dev/null; then
    systemctl stop cloudflared
    cloudflared service uninstall 2>/dev/null || true
  fi

  cloudflared service install

  systemctl enable cloudflared
  systemctl start cloudflared

  # Wait up to 10s for service to stabilize
  local i=0
  while [ $i -lt 5 ]; do
    sleep 2
    i=$((i + 1))
    if systemctl is-active --quiet cloudflared; then
      print_ok "cloudflared service is running."
      return 0
    fi
  done

  print_error "cloudflared service failed to start."
  print_info "Last 20 log lines:"
  journalctl -u cloudflared -n 20 --no-pager 2>/dev/null || true
  exit 1
}

setup_tunnel() {
  install_cloudflared
  cloudflared_login
  create_tunnel
  generate_config
  route_dns
  install_tunnel_service
}
