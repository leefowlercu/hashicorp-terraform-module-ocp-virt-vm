# Kubernetes Authentication Variables
variable "kubeconfig_path" {
  description = "Path to kubeconfig file for authentication"
  type        = string
  default     = null
}

variable "cluster_host" {
  description = "Kubernetes API server host URL"
  type        = string
  default     = null
}

variable "cluster_token" {
  description = "Kubernetes authentication token"
  type        = string
  default     = null
  sensitive   = true
}

variable "cluster_insecure" {
  description = "Allow insecure TLS connections to the cluster"
  type        = bool
  default     = false
}

# Packer Configuration Variables
variable "packer_enabled" {
  description = "Enable Packer image build (if false, must provide pre-built image)"
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
  description = "Red Hat subscription username (optional, for package updates during build)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "rhel_subscription_password" {
  description = "Red Hat subscription password (optional, for package updates during build)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "packer_output_dir" {
  description = "Directory for Packer build output"
  type        = string
  default     = "output"
}

# Vault Configuration Variables
variable "vault_version" {
  description = "HashiCorp Vault version to install"
  type        = string
  default     = "1.15.0"
}

variable "vault_addr" {
  description = "Vault server address (e.g., https://vault.example.com:8200)"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace (optional, for Vault Enterprise)"
  type        = string
  default     = ""
}

variable "vault_auth_method" {
  description = "Vault authentication method (kubernetes, approle, aws, etc.)"
  type        = string
  default     = "kubernetes"
}

variable "vault_role" {
  description = "Vault role name for authentication"
  type        = string
}

variable "vault_secrets_config" {
  description = "Vault Agent template configuration for secrets (HCL format)"
  type        = string
  default     = ""
}

# Container Registry Variables
variable "registry_url" {
  description = "Container registry URL"
  type        = string
  default     = "quay.io"
}

variable "registry_username" {
  description = "Container registry username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "registry_password" {
  description = "Container registry password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "image_name" {
  description = "Name for the built container image (e.g., myorg/rhel10-vault-agent)"
  type        = string
}

variable "image_tag" {
  description = "Tag for the built container image"
  type        = string
  default     = "latest"
}

variable "prebuilt_image" {
  description = "Pre-built container image reference (only used if packer_enabled = false)"
  type        = string
  default     = ""
}

# VM Configuration Variables
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_namespace" {
  description = "Namespace where the virtual machine will be created"
  type        = string
  default     = "ocp-virt-tf-module-test"
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
  description = "Memory allocation for the virtual machine (e.g., '1Gi', '2048Mi')"
  type        = string
  default     = "2Gi"
}

variable "vm_disk_bus" {
  description = "Disk bus type (virtio, sata, scsi)"
  type        = string
  default     = "virtio"
}

variable "vm_network_name" {
  description = "Network name for the virtual machine (pod network uses 'default')"
  type        = string
  default     = "default"
}

variable "vm_network_interface_model" {
  description = "Network interface model (virtio, e1000, e1000e)"
  type        = string
  default     = "virtio"
}

variable "vm_labels" {
  description = "Labels to apply to the virtual machine"
  type        = map(string)
  default     = {}
}

variable "vm_annotations" {
  description = "Annotations to apply to the virtual machine"
  type        = map(string)
  default     = {}
}

variable "vm_termination_grace_period" {
  description = "Termination grace period in seconds"
  type        = number
  default     = 30
}

variable "vm_additional_cloudinit_config" {
  description = "Additional cloud-init configuration to append (optional)"
  type        = string
  default     = ""
}
