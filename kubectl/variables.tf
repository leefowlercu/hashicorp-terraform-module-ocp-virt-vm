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
  default     = 1
}

variable "vm_memory" {
  description = "Memory allocation for the virtual machine (e.g., '1Gi', '2048Mi')"
  type        = string
  default     = "1Gi"
}

variable "vm_disk_bus" {
  description = "Disk bus type (virtio, sata, scsi)"
  type        = string
  default     = "virtio"
}

variable "vm_volume_type" {
  description = "Volume type: containerDisk, dataVolume, or persistentVolumeClaim"
  type        = string
  default     = "containerDisk"

  validation {
    condition     = contains(["containerDisk", "dataVolume", "persistentVolumeClaim"], var.vm_volume_type)
    error_message = "Volume type must be one of: containerDisk, dataVolume, persistentVolumeClaim"
  }
}

variable "vm_container_image" {
  description = "Container image for containerDisk volume type (e.g., 'quay.io/containerdisks/fedora:latest')"
  type        = string
  default     = null
}

variable "vm_datavolume_source_http" {
  description = "HTTP URL source for DataVolume"
  type        = string
  default     = null
}

variable "vm_datavolume_size" {
  description = "Size of the DataVolume (e.g., '10Gi')"
  type        = string
  default     = "10Gi"
}

variable "vm_datavolume_storage_class" {
  description = "Storage class for DataVolume"
  type        = string
  default     = null
}

variable "vm_pvc_name" {
  description = "Name of existing PVC when using persistentVolumeClaim volume type"
  type        = string
  default     = null
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

variable "vm_cloudinit_userdata" {
  description = "Cloud-init user data for VM initialization"
  type        = string
  default     = null
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