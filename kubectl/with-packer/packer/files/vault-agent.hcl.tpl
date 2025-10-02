# This is a template file that will be customized by cloud-init at VM boot time
# The actual configuration will be written to /etc/vault.d/vault-agent.hcl

vault {
  address = "${VAULT_ADDR}"
}

auto_auth {
  method {
    type = "${VAULT_AUTH_METHOD}"

    config = {
      role = "${VAULT_ROLE}"
    }
  }

  sink {
    type = "file"
    config = {
      path = "/var/run/vault/token"
      mode = 0640
    }
  }
}

# Template blocks will be added by cloud-init based on vm_vault_secrets_config
${VAULT_TEMPLATES}
