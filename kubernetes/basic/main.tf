resource "kubernetes_manifest" "virtual_machine" {
  manifest = local.vm_manifest
}
