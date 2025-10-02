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
