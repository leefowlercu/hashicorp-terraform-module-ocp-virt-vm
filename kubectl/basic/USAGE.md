# kubectl Provider Module

Terraform module for managing KubeVirt VirtualMachines on OpenShift using the `gavinbunney/kubectl` provider.

## Overview

This module uses the `kubectl_manifest` resource to deploy and manage KubeVirt VirtualMachines on OpenShift clusters with OpenShift Virtualization installed. It provides a declarative way to define VM specifications including compute resources, storage, networking, and lifecycle configuration.

**This is the recommended version** for production use due to its clean state management and accurate drift detection.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubectl | >= 1.14.0 |
| kubernetes | >= 2.23.0 |

## Providers

| Name | Version |
|------|---------|
| kubectl | >= 1.14.0 |
| kubernetes | >= 2.23.0 |

## Resources

| Name | Type |
|------|------|
| kubectl_manifest.virtual_machine | resource |
| kubernetes_namespace.vm_namespace | data source |

## Module Usage

### Basic Usage

```hcl
module "vm" {
  source = "path/to/kubectl"

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
  source = "path/to/kubectl"

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
  source = "path/to/kubectl"

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
  source = "path/to/kubectl"

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
  source = "path/to/kubectl"

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

### Managing Multiple VMs

```hcl
locals {
  vms = {
    web = {
      cpu_cores = 2
      memory    = "4Gi"
      image     = "quay.io/containerdisks/fedora:latest"
    }
    db = {
      cpu_cores = 4
      memory    = "8Gi"
      image     = "quay.io/containerdisks/centos-stream:9"
    }
  }
}

module "vms" {
  for_each = local.vms
  source   = "path/to/kubectl"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "${each.key}-vm"
  vm_namespace = "virtualization"

  vm_cpu_cores = each.value.cpu_cores
  vm_memory    = each.value.memory

  vm_volume_type     = "containerDisk"
  vm_container_image = each.value.image

  vm_labels = {
    role        = each.key
    environment = "production"
  }
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
| vm_status | Status of the virtual machine (always null with kubectl provider) |
| vm_object | Full virtual machine YAML as parsed by the provider |

## Advantages

### ✅ Clean State Management

The kubectl provider handles complex CRDs without type validation errors:

- No "Provider produced inconsistent result" errors
- Clean apply operations every time
- No need for workarounds or manual imports

### ✅ Accurate Drift Detection

```bash
terraform plan
# Shows: No changes. Your infrastructure matches the configuration.
```

The kubectl provider accurately detects drift without false positives.

### ✅ Server-Side Apply

Uses Kubernetes server-side apply for better compatibility with:
- Admission webhooks
- Mutating controllers
- Default value injection

### ✅ YAML Native

Works with raw YAML manifests internally, same as `kubectl apply`, providing:
- Better compatibility with Kubernetes tooling
- Predictable behavior matching kubectl
- Easier debugging

## Features

- ✅ Support for multiple volume types (containerDisk, DataVolume, PVC)
- ✅ Configurable CPU, memory, and disk resources
- ✅ Cloud-init support for VM initialization
- ✅ Custom labels and annotations
- ✅ Network configuration
- ✅ VM lifecycle management (start/stop/delete)
- ✅ Namespace validation
- ✅ Clean state management (no reconciliation errors)
- ✅ Accurate drift detection
- ✅ Server-side apply support

## Provider Configuration

The module requires both kubectl and kubernetes providers to be configured in the calling module:

```hcl
provider "kubectl" {
  config_path = "~/.kube/config"
  # OR
  host  = var.cluster_host
  token = var.cluster_token
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  # OR
  host  = var.cluster_host
  token = var.cluster_token
}
```

## Examples

See the [examples/kubectl/basic](../examples/kubectl/basic/) directory for a complete working example.

## Comparison with kubernetes Module

| Feature | kubernetes Module | kubectl Module |
|---------|------------------|----------------|
| State Management | ❌ Type validation errors | ✅ Clean |
| Drift Detection | ⚠️ May show false changes | ✅ Accurate |
| Complex CRDs | ❌ Validation issues | ✅ Works well |
| Resource Definition | HCL object | YAML string |
| Server-Side Apply | Limited | ✅ Full support |
| Production Ready | ⚠️ With workarounds | ✅ Yes |
| Recommended | No | **Yes** |

## Migration from kubernetes Module

To migrate from the kubernetes module:

1. Update the module source path
2. No changes to variables needed (same inputs)
3. Run `terraform init -upgrade` to get the kubectl provider
4. Destroy the old resource and recreate with kubectl provider:

```bash
terraform destroy -target=module.vm.kubernetes_manifest.virtual_machine
terraform apply
```

Or use `terraform state mv` if downtime is not acceptable.

## License

This module follows the same license as the parent repository.
