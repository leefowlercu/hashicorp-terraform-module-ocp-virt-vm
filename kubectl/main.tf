resource "kubectl_manifest" "virtual_machine" {
  yaml_body = local.vm_manifest_yaml

  force_conflicts   = false
  server_side_apply = true

  wait = true
}
