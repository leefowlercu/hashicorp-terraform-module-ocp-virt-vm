provider "kubectl" {
  config_path = var.kubeconfig_path
  host        = var.cluster_host
  token       = var.cluster_token

  insecure = var.cluster_insecure
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
  host        = var.cluster_host
  token       = var.cluster_token

  insecure = var.cluster_insecure
}
