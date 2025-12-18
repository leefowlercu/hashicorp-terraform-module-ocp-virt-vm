# Kubernetes Provider Module

Terraform module for managing KubeVirt VirtualMachines on OpenShift using the `hashicorp/kubernetes` provider.

## Overview

This module uses the `kubernetes_manifest` resource to deploy and manage KubeVirt VirtualMachines on OpenShift clusters with OpenShift Virtualization installed. It provides a declarative way to define VM specifications including compute resources, storage, networking, and lifecycle configuration.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubernetes | >= 3.0.1 |

## Providers

| Name | Version |
|------|---------|
| kubernetes | >= 3.0.1 |

## Resources

| Name | Type |
|------|------|
| kubernetes_manifest.virtual_machine | resource |
| kubernetes_namespace_v1.vm_namespace | data source |

## Module Usage

### Basic Usage

```hcl
module "vm" {
  source = "path/to/kubernetes"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "my-vm"
  vm_namespace = "virtualization"
  vm_running   = true

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type     = "containerDisk"
  vm_container_image = "quay.io/containerdisks/fedora:latest"

  vm_labels = {
    environment = "production"
    application = "web-server"
  }
}
```

### Using with Token Authentication

```hcl
module "vm" {
  source = "path/to/kubernetes"

  cluster_host  = "https://api.cluster.example.com:6443"
  cluster_token = var.openshift_token

  vm_name      = "my-vm"
  vm_namespace = "virtualization"

  vm_cpu_cores = 4
  vm_memory    = "8Gi"

  vm_volume_type     = "containerDisk"
  vm_container_image = "quay.io/containerdisks/centos-stream:9"
}
```

### Using DataVolume with HTTP Source

```hcl
module "vm" {
  source = "path/to/kubernetes"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "centos-vm"
  vm_namespace = "virtualization"

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type            = "dataVolume"
  vm_datavolume_source_http = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
  vm_datavolume_size        = "30Gi"
  vm_datavolume_storage_class = "gp3-csi"
}
```

### Using Existing PVC

```hcl
module "vm" {
  source = "path/to/kubernetes"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "persistent-vm"
  vm_namespace = "virtualization"

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type = "persistentVolumeClaim"
  vm_pvc_name    = "my-existing-pvc"
}
```

### With Cloud-Init Configuration

```hcl
module "vm" {
  source = "path/to/kubernetes"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "configured-vm"
  vm_namespace = "virtualization"

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type     = "containerDisk"
  vm_container_image = "quay.io/containerdisks/fedora:latest"

  vm_cloudinit_userdata = <<-EOT
    #cloud-config
    users:
      - name: fedora
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ssh-rsa AAAA...your-public-key
    packages:
      - nginx
      - git
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
  EOT
}
```

## Inputs

### Authentication Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| kubeconfig_path | Path to kubeconfig file | `string` | `null` | no |
| cluster_host | Kubernetes API server host URL | `string` | `null` | no |
| cluster_token | Kubernetes authentication token | `string` | `null` | no |
| cluster_insecure | Allow insecure TLS connections | `bool` | `false` | no |

### VM Configuration Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vm_name | Name of the virtual machine | `string` | n/a | yes |
| vm_namespace | Namespace for the VM | `string` | `"ocp-virt-tf-module-test"` | no |
| vm_running | Desired running state | `bool` | `true` | no |
| vm_cpu_cores | Number of CPU cores | `number` | `1` | no |
| vm_memory | Memory allocation (e.g., '1Gi', '2048Mi') | `string` | `"1Gi"` | no |
| vm_disk_bus | Disk bus type (virtio, sata, scsi) | `string` | `"virtio"` | no |

### Volume Configuration Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vm_volume_type | Volume type: containerDisk, dataVolume, or persistentVolumeClaim | `string` | `"containerDisk"` | no |
| vm_container_image | Container image for containerDisk | `string` | `null` | no |
| vm_datavolume_source_http | HTTP URL source for DataVolume | `string` | `null` | no |
| vm_datavolume_size | Size of the DataVolume | `string` | `"10Gi"` | no |
| vm_datavolume_storage_class | Storage class for DataVolume | `string` | `null` | no |
| vm_pvc_name | Name of existing PVC | `string` | `null` | no |

### Network Configuration Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vm_network_name | Network name for the VM | `string` | `"default"` | no |
| vm_network_interface_model | Network interface model | `string` | `"virtio"` | no |

### Additional Configuration Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vm_cloudinit_userdata | Cloud-init user data | `string` | `null` | no |
| vm_labels | Labels to apply to the VM | `map(string)` | `{}` | no |
| vm_annotations | Annotations to apply to the VM | `map(string)` | `{}` | no |
| vm_termination_grace_period | Termination grace period in seconds | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_name | Name of the virtual machine |
| vm_namespace | Namespace of the virtual machine |
| vm_uid | UID of the virtual machine |
| vm_resource_version | Resource version of the virtual machine |
| vm_status | Status of the virtual machine |
| vm_object | Full virtual machine object as returned by the Kubernetes API |

## Known Limitations

### State Reconciliation Error

The `kubernetes_manifest` resource produces the following error after successfully creating resources:

```
Error: Provider produced inconsistent result after apply

When applying changes to module.vm.kubernetes_manifest.virtual_machine,
provider "module.vm.provider["registry.terraform.io/hashicorp/kubernetes"]"
produced an unexpected new value: .object: wrong final value type:
incorrect object attributes.

This is a bug in the provider, which should be reported in the provider's
own issue tracker.
```

#### Root Cause

This error occurs due to a fundamental limitation in how the `kubernetes_manifest` resource validates complex CRD schemas:

1. **HCL-to-CRD Type Validation**: The kubernetes provider converts HCL objects to Kubernetes resources and then validates the API server's response against the expected schema
2. **API Server Enrichment**: The Kubernetes API server adds default values, metadata, and type conversions to the resource (e.g., converting empty objects `{}` to `null`, adding computed fields like `machine.type`)
3. **Schema Mismatch**: The provider's type validator cannot reconcile these enrichments with the original HCL structure, especially for deeply nested CRDs like KubeVirt VirtualMachine

#### What We Tested (October 2025)

We performed comprehensive testing against a live OpenShift cluster with OpenShift Virtualization to determine if this issue could be resolved:

**Test 1: Provider Version Upgrade**
- Updated from `>= 2.23.0` to `~> 2.38.0`
- Result: ❌ Error persists

**Test 2: Simplified `computed_fields`**
- Configuration: `["metadata.generation", "status"]` (minimal best practice)
- Set `force_conflicts = true`
- Removed `lifecycle { ignore_changes = [object] }`
- Result: ❌ Error persists

**Test 3: Extended `computed_fields`**
- Added 40+ computed field paths covering all nested structures
- Included `force_conflicts = true`
- Re-added `lifecycle { ignore_changes = [object] }`
- Result: ❌ Error persists

**Test 4: kubectl Provider (Comparison)**
- Same VM configuration using `kubectl_manifest` with `server_side_apply = true`
- Result: ✅ Works perfectly, no errors, no drift detection

#### Conclusion

**The error cannot be resolved through configuration changes.** It is a fundamental limitation of the `kubernetes_manifest` resource when working with complex CRDs that have:
- Deeply nested optional fields
- Server-side type conversions
- Extensive default value enrichment

The VirtualMachine **is created successfully** in the cluster despite the Terraform error, but Terraform's state management is broken.

### Workaround

1. Verify the VM was created: `oc get vm <vm-name> -n <namespace>`
2. Import the resource into state:

```bash
terraform import 'module.vm.kubernetes_manifest.virtual_machine' \
  "apiVersion=kubevirt.io/v1,kind=VirtualMachine,namespace=<namespace>,name=<vm-name>"
```

3. Continue normal terraform operations (subsequent applies may still show the error)

### Recommended Solution

**Use the kubectl provider version instead.** The `kubectl/basic` module uses the `gavinbunney/kubectl` provider which:
- Handles manifests as YAML strings (via `yamlencode()`)
- Uses Server-Side Apply without HCL-to-CRD type validation
- Has clean state management without false drift
- Is production-ready for managing KubeVirt VirtualMachines

See: `../kubectl/basic/` for the recommended implementation.

## Features

- ✅ Support for multiple volume types (containerDisk, DataVolume, PVC)
- ✅ Configurable CPU, memory, and disk resources
- ✅ Cloud-init support for VM initialization
- ✅ Custom labels and annotations
- ✅ Network configuration
- ✅ VM lifecycle management (start/stop/delete)
- ✅ Namespace validation

## Provider Configuration

The module requires the kubernetes provider to be configured in the calling module:

```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
  # OR
  host  = var.cluster_host
  token = var.cluster_token
}
```

## Examples

See the [examples/kubernetes/basic](../examples/kubernetes/basic/) directory for a complete working example.

## Comparison with kubectl Module

| Feature | kubernetes Module | kubectl Module |
|---------|------------------|----------------|
| State Management | ⚠️ Type validation errors | ✅ Clean |
| Drift Detection | ⚠️ May show false changes | ✅ Accurate |
| Complex CRDs | ❌ Validation issues | ✅ Works well |
| Resource Definition | HCL object | YAML string |
| Production Ready | ⚠️ With workarounds | ✅ Yes |

## License

This module follows the same license as the parent repository.
