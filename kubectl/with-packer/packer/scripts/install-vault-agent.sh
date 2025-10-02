#!/bin/bash
set -e

VAULT_VERSION="${VAULT_VERSION:-1.15.0}"

echo "Installing HashiCorp Vault ${VAULT_VERSION}..."

# Download and install Vault binary
cd /tmp
curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o vault.zip
unzip vault.zip
sudo mv vault /usr/local/bin/
sudo chmod +x /usr/local/bin/vault
rm vault.zip

# Verify installation
/usr/local/bin/vault version

# Create vault user and directories
sudo useradd --system --home /etc/vault.d --shell /bin/false vault || true
sudo mkdir -p /etc/vault.d
sudo mkdir -p /var/run/vault
sudo chown -R vault:vault /etc/vault.d
sudo chown -R vault:vault /var/run/vault
sudo chmod 700 /etc/vault.d

# Create systemd unit file for Vault Agent
cat <<EOF | sudo tee /etc/systemd/system/vault-agent.service
[Unit]
Description=HashiCorp Vault Agent
Documentation=https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=vault
Group=vault
ExecStart=/usr/local/bin/vault agent -config=/etc/vault.d/vault-agent.hcl
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service (but don't start - cloud-init will configure and start)
sudo systemctl daemon-reload
sudo systemctl enable vault-agent.service

echo "Vault Agent installation complete!"
