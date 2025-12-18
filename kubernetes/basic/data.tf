data "kubernetes_namespace_v1" "vm_namespace" {
  metadata {
    name = var.vm_namespace
  }
}