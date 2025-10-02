data "kubernetes_namespace" "vm_namespace" {
  metadata {
    name = var.vm_namespace
  }
}
