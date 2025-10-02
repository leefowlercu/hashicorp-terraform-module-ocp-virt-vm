locals {
  # Build the root disk volume based on volume type
  root_volume = var.vm_volume_type == "containerDisk" ? {
    name = "rootdisk"
    containerDisk = {
      image = var.vm_container_image
    }
    } : var.vm_volume_type == "dataVolume" ? {
    name = "rootdisk"
    dataVolume = {
      name = "${var.vm_name}-dv"
    }
    } : {
    name = "rootdisk"
    persistentVolumeClaim = {
      claimName = var.vm_pvc_name
    }
  }

  # Cloud-init volume (optional)
  cloudinit_volume = var.vm_cloudinit_userdata != null ? {
    name = "cloudinit"
    cloudInitNoCloud = {
      userData = var.vm_cloudinit_userdata
    }
  } : null

  # Cloud-init disk (optional)
  cloudinit_disk = var.vm_cloudinit_userdata != null ? {
    name = "cloudinit"
    disk = {
      bus = "virtio"
    }
  } : null

  # All volumes
  all_volumes = concat(
    [local.root_volume],
    var.vm_cloudinit_userdata != null ? [local.cloudinit_volume] : []
  )

  # All disks
  all_disks = concat(
    [{
      name = "rootdisk"
      disk = {
        bus = var.vm_disk_bus
      }
    }],
    var.vm_cloudinit_userdata != null ? [local.cloudinit_disk] : []
  )

  # DataVolume template (only for dataVolume type)
  datavolume_templates = var.vm_volume_type == "dataVolume" ? [{
    metadata = {
      name = "${var.vm_name}-dv"
    }
    spec = {
      storage = {
        resources = {
          requests = {
            storage = var.vm_datavolume_size
          }
        }
        storageClassName = var.vm_datavolume_storage_class
      }
      source = var.vm_datavolume_source_http != null ? {
        http = {
          url = var.vm_datavolume_source_http
        }
      } : {}
    }
  }] : []

  # Complete VM manifest
  vm_manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name        = var.vm_name
      namespace   = data.kubernetes_namespace.vm_namespace.metadata[0].name
      labels      = var.vm_labels
      annotations = var.vm_annotations
    }
    spec = merge(
      {
        running = var.vm_running
        template = {
          metadata = {
            labels = merge(
              var.vm_labels,
              {
                "kubevirt.io/vm" = var.vm_name
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
      },
      length(local.datavolume_templates) > 0 ? {
        dataVolumeTemplates = local.datavolume_templates
      } : {}
    )
  }

  # Convert manifest to YAML for kubectl provider
  vm_manifest_yaml = yamlencode(local.vm_manifest)
}
