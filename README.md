# OpenShift Virtualization Terraform Module

Terraform modules for managing KubeVirt VirtualMachines on Red Hat OpenShift clusters.

**Current Version**: N/A

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Available Modules](#available-modules)
- [Requirements](#requirements)
- [Authentication](#authentication)
- [Usage Examples](#usage-examples)
- [Module Documentation](#module-documentation)

## Overview

This repository provides Terraform modules for deploying and managing KubeVirt VirtualMachines on OpenShift clusters with OpenShift Virtualization installed. Three module implementations are available to suit different use cases:

- **kubectl/basic** (Recommended) - Production-ready module using the `gavinbunney/kubectl` provider with YAML-based manifests and server-side apply. Provides clean state management and accurate drift detection.

- **kubernetes/basic** (Legacy) - Alternative implementation using the `hashicorp/kubernetes` provider with HCL-based manifests. Has known state reconciliation issues with complex CRDs that cannot be resolved through configuration.

- **kubectl/with-packer** (Advanced) - Extends kubectl/basic with Packer integration for building custom RHEL 10 images with Vault Agent pre-installed. Suitable for environments requiring secrets management integration.

## Quick Start

### Prerequisites

- Red Hat OpenShift cluster with OpenShift Virtualization operator installed
- Terraform >= 1.0
- kubectl or oc CLI configured with cluster access

### Using kubectl/basic (Recommended)

```bash
# Verify OpenShift Virtualization is installed
oc get csv -n openshift-cnv

# Create namespace for VMs
oc create namespace virtualization

# Copy the example configuration
cp -r examples/kubectl/basic my-vm-config
cd my-vm-config

# Configure your variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Deploy
terraform init
terraform plan
terraform apply

# Verify
oc get vm -n virtualization
oc get vmi -n virtualization
```

## Available Modules

| Module | Provider | Status | Description |
|--------|----------|--------|-------------|
| [kubectl/basic](kubectl/basic/) | gavinbunney/kubectl | Recommended | Basic VM deployment with clean state management |
| [kubernetes/basic](kubernetes/basic/) | hashicorp/kubernetes | Legacy | Alternative with known state reconciliation issues |
| [kubectl/with-packer](kubectl/with-packer/) | kubectl + null | Advanced | Custom RHEL 10 images with Vault Agent |

## Requirements

### Terraform

| Name | Version |
|------|---------|
| terraform | >= 1.0 |

### Providers

**kubectl modules:**
- kubectl >= 1.14.0
- kubernetes >= 2.23.0

**kubernetes module:**
- kubernetes ~> 3.0.1

**kubectl/with-packer module (additional):**
- null >= 3.0

### Cluster Requirements

- Red Hat OpenShift cluster (ROSA, ARO, OCP on-prem)
- OpenShift Virtualization operator installed
- KubeVirt CRDs available
- Appropriate storage classes configured (e.g., gp3-csi for AWS)

## Authentication

### Kubeconfig File

```hcl
kubeconfig_path = "~/.kube/config"
```

### Token Authentication (CI/CD)

```hcl
cluster_host  = "https://api.cluster.example.com:6443"
cluster_token = var.openshift_token
```

## Usage Examples

### Basic VM with containerDisk

```hcl
module "vm" {
  source = "./kubectl/basic"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "fedora-vm"
  vm_namespace = "virtualization"
  vm_running   = true

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type     = "containerDisk"
  vm_container_image = "quay.io/containerdisks/fedora:latest"
}
```

### VM with DataVolume from HTTP Source

```hcl
module "vm" {
  source = "./kubectl/basic"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "centos-vm"
  vm_namespace = "virtualization"

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type              = "dataVolume"
  vm_datavolume_source_http   = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
  vm_datavolume_size          = "30Gi"
  vm_datavolume_storage_class = "gp3-csi"
}
```

### VM with Cloud-Init

```hcl
module "vm" {
  source = "./kubectl/basic"

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

### Multiple VMs with for_each

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
  source   = "./kubectl/basic"

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

## Module Documentation

### Module Reference

- [kubectl/basic Module](kubectl/basic/USAGE.md) - Recommended
- [kubectl/with-packer Module](kubectl/with-packer/USAGE.md) - Advanced
- [kubernetes/basic Module](kubernetes/basic/USAGE.md) - Legacy

### Example Reference

- [kubectl/basic Example](examples/kubectl/basic/USAGE.md)
- [kubectl/with-packer Example](examples/kubectl/with-packer/USAGE.md)
- [kubernetes/basic Example](examples/kubernetes/basic/USAGE.md)

### Additional Documentation

- [kubernetes Provider Bug Report](docs/kubernetes-provider-bug.md) - Detailed analysis of the kubernetes_manifest state reconciliation issue
