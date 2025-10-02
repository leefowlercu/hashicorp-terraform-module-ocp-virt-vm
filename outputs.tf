output "vm_name" {
  description = "Name of the virtual machine"
  value       = kubernetes_manifest.virtual_machine.object.metadata.name
}

output "vm_namespace" {
  description = "Namespace of the virtual machine"
  value       = kubernetes_manifest.virtual_machine.object.metadata.namespace
}

output "vm_uid" {
  description = "UID of the virtual machine"
  value       = kubernetes_manifest.virtual_machine.object.metadata.uid
}

output "vm_resource_version" {
  description = "Resource version of the virtual machine"
  value       = kubernetes_manifest.virtual_machine.object.metadata.resourceVersion
}

output "vm_status" {
  description = "Status of the virtual machine"
  value       = try(kubernetes_manifest.virtual_machine.object.status, null)
}

output "vm_object" {
  description = "Full virtual machine object as returned by the Kubernetes API"
  value       = kubernetes_manifest.virtual_machine.object
}