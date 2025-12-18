variable "kubeconfig_path" {
  description = "Path to kubeconfig file for authentication"
  type        = string
  default     = "~/.kube/config"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "test-vm"
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
  default     = 1
}

variable "vm_memory" {
  description = "Memory allocation for the virtual machine"
  type        = string
  default     = "2Gi"
}

variable "vm_volume_type" {
  description = "Volume type: containerDisk, dataVolume, or persistentVolumeClaim"
  type        = string
  default     = "dataVolume"
}

variable "vm_container_image" {
  description = "Container image for containerDisk volume type"
  type        = string
  default     = null
}

variable "vm_datavolume_source_ref_name" {
  description = "Name of DataSource to use (e.g., 'fedora', 'rhel9', 'centos-stream9')"
  type        = string
  default     = "fedora"
}

variable "vm_datavolume_size" {
  description = "Size of the DataVolume"
  type        = string
  default     = "10Gi"
}