resource "kubernetes_manifest" "virtual_machine" {
  manifest = local.vm_manifest

  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "metadata.finalizers",
    "spec.runStrategy",
    "spec.template.metadata",
    "spec.template.spec.architecture",
    "spec.template.spec.domain.cpu",
    "spec.template.spec.domain.devices",
    "spec.template.spec.domain.firmware",
    "spec.template.spec.domain.machine",
    "spec.template.spec.domain.resources",
    "status"
  ]

  # wait {
  #   condition {
  #     type   = "Ready"
  #     status = "True"
  #   }
  # }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }

  field_manager {
    force_conflicts = false
  }

  lifecycle {
    ignore_changes = [
      object
    ]
  }
}