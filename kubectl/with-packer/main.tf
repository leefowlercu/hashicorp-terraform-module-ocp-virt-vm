# Build custom RHEL 10 image with Vault Agent using Packer
resource "null_resource" "packer_build" {
  count = var.packer_enabled ? 1 : 0

  triggers = {
    packer_template     = filemd5("${path.module}/packer/rhel10.pkr.hcl")
    install_script      = filemd5("${path.module}/packer/scripts/install-vault-agent.sh")
    vault_config_tpl    = filemd5("${path.module}/packer/files/vault-agent.hcl.tpl")
    vault_version       = var.vault_version
    image_tag           = var.image_tag
    rhel10_image_url    = var.rhel10_image_url
    rhel10_image_checksum = var.rhel10_image_checksum
  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/build-and-push.sh"
    working_dir = path.module

    environment = {
      PACKER_DIR             = "packer"
      OUTPUT_DIR             = var.packer_output_dir
      RHEL10_IMAGE_URL       = var.rhel10_image_url
      RHEL10_IMAGE_CHECKSUM  = var.rhel10_image_checksum
      VAULT_VERSION          = var.vault_version
      RHEL_SUB_USERNAME      = var.rhel_subscription_username
      RHEL_SUB_PASSWORD      = var.rhel_subscription_password
      IMAGE_NAME             = var.image_name
      IMAGE_TAG              = var.image_tag
      REGISTRY_URL           = var.registry_url
      REGISTRY_USERNAME      = var.registry_username
      REGISTRY_PASSWORD      = var.registry_password
      VM_NAME                = "${var.vm_name}-base"
    }
  }
}

# Deploy VM using the built image with Vault Agent
resource "kubectl_manifest" "virtual_machine" {
  depends_on = [null_resource.packer_build]

  yaml_body = local.vm_manifest_yaml

  force_conflicts   = false
  server_side_apply = true

  wait = true
}
