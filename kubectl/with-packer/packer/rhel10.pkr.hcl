packer {
  required_version = ">= 1.8.0"
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "rhel10_image_url" {
  type        = string
  description = "URL to RHEL 10 KVM Guest Image (qcow2)"
}

variable "rhel10_image_checksum" {
  type        = string
  description = "Checksum for RHEL 10 image verification (format: type:value, e.g., sha256:abc123...)"
}

variable "vault_version" {
  type        = string
  default     = "1.15.0"
  description = "HashiCorp Vault version to install"
}

variable "rhel_subscription_username" {
  type        = string
  default     = ""
  description = "Red Hat subscription username (optional, for package updates)"
  sensitive   = true
}

variable "rhel_subscription_password" {
  type        = string
  default     = ""
  description = "Red Hat subscription password (optional, for package updates)"
  sensitive   = true
}

variable "output_directory" {
  type        = string
  default     = "output"
  description = "Directory for Packer build output"
}

variable "vm_name" {
  type        = string
  default     = "rhel10-vault-agent"
  description = "Name for the output image"
}

source "qemu" "rhel10" {
  iso_url           = var.rhel10_image_url
  iso_checksum      = var.rhel10_image_checksum
  output_directory  = var.output_directory
  shutdown_command  = "echo 'packer' | sudo -S shutdown -P now"
  disk_image        = true
  disk_size         = "20G"
  format            = "qcow2"
  accelerator       = "kvm"
  http_directory    = "http"
  ssh_username      = "cloud-user"
  ssh_password      = "cloud-user"
  ssh_timeout       = "20m"
  vm_name           = "${var.vm_name}.qcow2"
  net_device        = "virtio-net"
  disk_interface    = "virtio"
  boot_wait         = "10s"
  boot_command      = []
  headless          = true
  memory            = 2048
  cpus              = 2

  qemuargs = [
    ["-serial", "stdio"],
    ["-display", "none"]
  ]
}

build {
  sources = ["source.qemu.rhel10"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait || true",
      "sudo cloud-init status --wait || true"
    ]
  }

  # Register with Red Hat Subscription Manager (if credentials provided)
  provisioner "shell" {
    inline = [
      "if [ -n '${var.rhel_subscription_username}' ] && [ -n '${var.rhel_subscription_password}' ]; then",
      "  echo 'Registering with Red Hat Subscription Manager...'",
      "  sudo subscription-manager register --username='${var.rhel_subscription_username}' --password='${var.rhel_subscription_password}' --auto-attach || true",
      "else",
      "  echo 'Skipping RHSM registration (no credentials provided)'",
      "fi"
    ]
  }

  # Update system packages
  provisioner "shell" {
    inline = [
      "echo 'Updating system packages...'",
      "sudo dnf update -y || true",
      "sudo dnf install -y curl unzip systemd"
    ]
  }

  # Install Vault Agent
  provisioner "shell" {
    script = "scripts/install-vault-agent.sh"
    environment_vars = [
      "VAULT_VERSION=${var.vault_version}"
    ]
  }

  # Upload Vault Agent config template
  provisioner "file" {
    source      = "files/vault-agent.hcl.tpl"
    destination = "/tmp/vault-agent.hcl.tpl"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/vault.d",
      "sudo mv /tmp/vault-agent.hcl.tpl /etc/vault.d/vault-agent.hcl.tpl",
      "sudo chown vault:vault /etc/vault.d/vault-agent.hcl.tpl",
      "sudo chmod 640 /etc/vault.d/vault-agent.hcl.tpl"
    ]
  }

  # Unregister from RHSM (cleanup)
  provisioner "shell" {
    inline = [
      "if [ -n '${var.rhel_subscription_username}' ]; then",
      "  echo 'Unregistering from Red Hat Subscription Manager...'",
      "  sudo subscription-manager unregister || true",
      "  sudo subscription-manager clean || true",
      "else",
      "  echo 'Skipping RHSM unregistration'",
      "fi"
    ]
  }

  # Clean cloud-init to allow re-initialization
  provisioner "shell" {
    inline = [
      "echo 'Cleaning cloud-init state...'",
      "sudo cloud-init clean --logs --seed",
      "sudo rm -rf /var/lib/cloud/instances/*",
      "sudo rm -rf /var/lib/cloud/instance",
      "sudo rm -f /var/log/cloud-init*.log"
    ]
  }

  # Clean up package caches and temporary files
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo dnf clean all",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "sudo rm -f /root/.bash_history",
      "sudo rm -f /home/*/.bash_history"
    ]
  }
}
