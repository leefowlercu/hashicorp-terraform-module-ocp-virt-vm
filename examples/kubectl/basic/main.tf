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

module "vm" {
  source = "../../../kubectl"

  kubeconfig_path = var.kubeconfig_path

  vm_name      = var.vm_name
  vm_namespace = var.vm_namespace
  vm_running   = var.vm_running

  vm_cpu_cores = var.vm_cpu_cores
  vm_memory    = var.vm_memory

  vm_volume_type     = var.vm_volume_type
  vm_container_image = var.vm_container_image

  vm_labels = {
    environment = "test"
    managed-by  = "terraform"
  }

  vm_annotations = {
    description = "Example VM created by Terraform with kubectl provider"
  }
}

output "vm_name" {
  description = "Name of the created virtual machine"
  value       = module.vm.vm_name
}

output "vm_namespace" {
  description = "Namespace of the created virtual machine"
  value       = module.vm.vm_namespace
}

output "vm_uid" {
  description = "UID of the created virtual machine"
  value       = module.vm.vm_uid
}

output "vm_status" {
  description = "Status of the created virtual machine"
  value       = module.vm.vm_status
}
