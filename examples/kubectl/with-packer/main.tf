terraform {
  required_version = ">= 1.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "kubectl" {
  config_path = var.kubeconfig_path
}

module "vault_agent_vm" {
  source = "../../../kubectl/with-packer"

  # Kubernetes authentication
  kubeconfig_path = var.kubeconfig_path

  # Packer configuration - RHEL 10
  packer_enabled            = var.packer_enabled
  rhel10_image_url          = var.rhel10_image_url
  rhel10_image_checksum     = var.rhel10_image_checksum
  rhel_subscription_username = var.rhel_subscription_username
  rhel_subscription_password = var.rhel_subscription_password

  # Vault configuration
  vault_version     = var.vault_version
  vault_addr        = var.vault_addr
  vault_namespace   = var.vault_namespace
  vault_auth_method = var.vault_auth_method
  vault_role        = var.vault_role
  vault_secrets_config = var.vault_secrets_config

  # Container registry configuration
  registry_url      = var.registry_url
  registry_username = var.registry_username
  registry_password = var.registry_password
  image_name        = var.image_name
  image_tag         = var.image_tag

  # VM configuration
  vm_name      = var.vm_name
  vm_namespace = var.vm_namespace
  vm_running   = var.vm_running
  vm_cpu_cores = var.vm_cpu_cores
  vm_memory    = var.vm_memory

  vm_labels = {
    environment = "test"
    managed-by  = "terraform"
    component   = "vault-agent-vm"
  }

  vm_annotations = {
    description = "VM with RHEL 10 and Vault Agent built by Packer"
  }
}

output "vm_name" {
  description = "Name of the created virtual machine"
  value       = module.vault_agent_vm.vm_name
}

output "vm_namespace" {
  description = "Namespace of the created virtual machine"
  value       = module.vault_agent_vm.vm_namespace
}

output "vm_uid" {
  description = "UID of the created virtual machine"
  value       = module.vault_agent_vm.vm_uid
}

output "container_image" {
  description = "Container image used for the VM"
  value       = module.vault_agent_vm.container_image
}

output "full_image_reference" {
  description = "Full container image reference"
  value       = module.vault_agent_vm.full_image_reference
}
