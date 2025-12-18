# Basic VM Example

This example creates a KubeVirt VirtualMachine on OpenShift using the `hashicorp/kubernetes` provider.

## Overview

Deploys a Fedora VM using pre-installed OS images from OpenShift Virtualization DataSources.

## Usage

```bash
# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars

# Deploy
terraform init
terraform apply

# Verify
oc get vm test-vm
oc get vmi test-vm

# Cleanup
terraform destroy
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubernetes | ~> 3.0 |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| kubeconfig_path | Path to kubeconfig file | string | `~/.kube/config` |
| vm_name | Name of the virtual machine | string | `test-vm` |
| vm_namespace | Namespace for the VM | string | `default` |
| vm_running | Start VM after creation | bool | `true` |
| vm_cpu_cores | Number of CPU cores | number | `1` |
| vm_memory | Memory allocation | string | `2Gi` |
| vm_volume_type | Volume type (dataVolume, containerDisk, persistentVolumeClaim) | string | `dataVolume` |
| vm_datavolume_source_ref_name | DataSource name (fedora, rhel9, centos-stream9) | string | `fedora` |
| vm_datavolume_size | DataVolume size | string | `10Gi` |
| vm_container_image | Container image for containerDisk | string | `null` |

## Outputs

| Name | Description |
|------|-------------|
| vm_name | Name of the created VM |
| vm_namespace | Namespace of the created VM |
| vm_uid | UID of the created VM |
| vm_status | Status of the created VM |

## Available OS Images

OpenShift Virtualization provides pre-installed DataSources:

- `fedora` - Fedora Linux
- `rhel9` - Red Hat Enterprise Linux 9
- `rhel8` - Red Hat Enterprise Linux 8
- `centos-stream9` - CentOS Stream 9
- `centos-stream10` - CentOS Stream 10

List available images:

```bash
oc get datasource -n openshift-virtualization-os-images
```

## Documentation

See [USAGE.md](USAGE.md) for detailed configuration options and troubleshooting.
