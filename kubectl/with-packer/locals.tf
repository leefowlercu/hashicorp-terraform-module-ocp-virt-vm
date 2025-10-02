locals {
  # Determine which container image to use
  container_image = var.packer_enabled ? "${var.registry_url}/${var.image_name}:${var.image_tag}" : var.prebuilt_image

  # Build Vault Agent cloud-init configuration
  vault_agent_cloudinit = templatefile("${path.module}/templates/vault-agent-cloudinit.yaml.tftpl", {
    vault_addr        = var.vault_addr
    vault_namespace   = var.vault_namespace
    vault_auth_method = var.vault_auth_method
    vault_role        = var.vault_role
    vault_templates   = var.vault_secrets_config
  })

  # Combine Vault Agent cloud-init with additional config
  cloudinit_userdata = var.vm_additional_cloudinit_config != "" ? "${local.vault_agent_cloudinit}\n${var.vm_additional_cloudinit_config}" : local.vault_agent_cloudinit

  # Root disk volume using containerDisk
  root_volume = {
    name = "rootdisk"
    containerDisk = {
      image = local.container_image
    }
  }

  # Cloud-init volume for Vault Agent configuration
  cloudinit_volume = {
    name = "cloudinit"
    cloudInitNoCloud = {
      userData = local.cloudinit_userdata
    }
  }

  # Cloud-init disk
  cloudinit_disk = {
    name = "cloudinit"
    disk = {
      bus = "virtio"
    }
  }

  # All volumes
  all_volumes = [
    local.root_volume,
    local.cloudinit_volume
  ]

  # All disks
  all_disks = [
    {
      name = "rootdisk"
      disk = {
        bus = var.vm_disk_bus
      }
    },
    local.cloudinit_disk
  ]

  # Complete VM manifest
  vm_manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name        = var.vm_name
      namespace   = data.kubernetes_namespace.vm_namespace.metadata[0].name
      labels      = merge(var.vm_labels, {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/component"  = "vault-agent"
      })
      annotations = var.vm_annotations
    }
    spec = {
      running = var.vm_running
      template = {
        metadata = {
          labels = merge(
            var.vm_labels,
            {
              "kubevirt.io/vm" = var.vm_name
              "app.kubernetes.io/component" = "vault-agent"
            }
          )
        }
        spec = {
          terminationGracePeriodSeconds = var.vm_termination_grace_period
          domain = {
            cpu = {
              cores = var.vm_cpu_cores
            }
            resources = {
              requests = {
                memory = var.vm_memory
              }
            }
            devices = {
              disks      = local.all_disks
              interfaces = [{
                name       = "default"
                model      = var.vm_network_interface_model
                masquerade = {}
              }]
            }
          }
          networks = [{
            name = "default"
            pod  = {}
          }]
          volumes = local.all_volumes
        }
      }
    }
  }

  # Convert manifest to YAML for kubectl provider
  vm_manifest_yaml = yamlencode(local.vm_manifest)
}
