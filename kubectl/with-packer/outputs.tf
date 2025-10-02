# VM Outputs
output "vm_name" {
  description = "Name of the virtual machine"
  value       = kubectl_manifest.virtual_machine.name
}

output "vm_namespace" {
  description = "Namespace of the virtual machine"
  value       = kubectl_manifest.virtual_machine.namespace
}

output "vm_uid" {
  description = "UID of the virtual machine"
  value       = kubectl_manifest.virtual_machine.uid
}

output "vm_resource_version" {
  description = "Resource version of the virtual machine"
  value       = kubectl_manifest.virtual_machine.live_uid
}

output "vm_status" {
  description = "Status of the virtual machine"
  value       = null
}

output "vm_object" {
  description = "Full virtual machine object as returned by the Kubernetes API"
  value       = kubectl_manifest.virtual_machine.yaml_body_parsed
}

# Image Outputs
output "container_image" {
  description = "Container image reference used for the VM"
  value       = local.container_image
}

output "image_name" {
  description = "Name of the built container image"
  value       = var.image_name
}

output "image_tag" {
  description = "Tag of the built container image"
  value       = var.image_tag
}

output "full_image_reference" {
  description = "Full container image reference (registry/name:tag)"
  value       = "${var.registry_url}/${var.image_name}:${var.image_tag}"
}
