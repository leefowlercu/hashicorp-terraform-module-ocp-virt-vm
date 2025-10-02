# Kubernetes Authentication
variable "kubeconfig_path" {
  description = "Path to kubeconfig file for authentication"
  type        = string
  default     = "~/.kube/config"
}

# Packer Configuration
variable "packer_enabled" {
  description = "Enable Packer image build"
  type        = bool
  default     = true
}

variable "rhel10_image_url" {
  description = "URL to RHEL 10 KVM Guest Image (qcow2)"
  type        = string
}

variable "rhel10_image_checksum" {
  description = "Checksum for RHEL 10 image (format: sha256:value)"
  type        = string
}

variable "rhel_subscription_username" {
  description = "Red Hat subscription username (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rhel_subscription_password" {
  description = "Red Hat subscription password (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

# Vault Configuration
variable "vault_version" {
  description = "HashiCorp Vault version to install"
  type        = string
  default     = "1.15.0"
}

variable "vault_addr" {
  description = "Vault server address"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace (optional, for Vault Enterprise)"
  type        = string
  default     = ""
}

variable "vault_auth_method" {
  description = "Vault authentication method"
  type        = string
  default     = "kubernetes"
}

variable "vault_role" {
  description = "Vault role name for authentication"
  type        = string
}

variable "vault_secrets_config" {
  description = "Vault Agent template configuration for secrets"
  type        = string
  default     = ""
}

# Container Registry
variable "registry_url" {
  description = "Container registry URL"
  type        = string
  default     = "quay.io"
}

variable "registry_username" {
  description = "Container registry username"
  type        = string
  sensitive   = true
}

variable "registry_password" {
  description = "Container registry password"
  type        = string
  sensitive   = true
}

variable "image_name" {
  description = "Name for the built container image"
  type        = string
  default     = "myorg/rhel10-vault-agent"
}

variable "image_tag" {
  description = "Tag for the built container image"
  type        = string
  default     = "latest"
}

# VM Configuration
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "vault-agent-vm"
}

variable "vm_namespace" {
  description = "Namespace where the virtual machine will be created"
  type        = string
  default     = "kubevirt-tf-module-test"
}

variable "vm_running" {
  description = "Desired running state of the virtual machine"
  type        = bool
  default     = true
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores for the virtual machine"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "Memory allocation for the virtual machine"
  type        = string
  default     = "4Gi"
}
