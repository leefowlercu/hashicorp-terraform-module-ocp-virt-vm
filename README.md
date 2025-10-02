# OpenShift Virtualization Terraform Module

Terraform modules for managing KubeVirt VirtualMachines on Red Hat OpenShift clusters with OpenShift Virtualization.

## Overview

This repository provides Terraform modules for deploying and managing KubeVirt VirtualMachines:

## Available Modules

### kubectl Provider Modules (Recommended)
- **kubectl/basic/** - Basic VM deployment using `gavinbunney/kubectl` provider
- **kubectl/with-packer/** - VM deployment with custom RHEL 10 images built by Packer with pre-installed Vault Agent

### kubernetes Provider Modules
- **kubernetes/basic/** - Basic VM deployment using `hashicorp/kubernetes` provider

The basic modules provide identical functionality and accept the same input variables, allowing you to choose the provider that best fits your requirements.

## Quick Start

### Using kubectl Provider (Recommended)

```hcl
module "vm" {
  source = "path/to/kubectl/basic"

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
  }
}
```

### Using kubernetes Provider

```hcl
module "vm" {
  source = "path/to/kubernetes/basic"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "my-vm"
  vm_namespace = "virtualization"
  vm_running   = true

  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_volume_type     = "containerDisk"
  vm_container_image = "quay.io/containerdisks/fedora:latest"
}
```

## Repository Structure

```
.
├── kubectl/
│   ├── basic/                    # Basic kubectl provider module (Recommended)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tf
│   │   ├── data.tf
│   │   ├── locals.tf
│   │   └── USAGE.md
│   └── with-packer/              # kubectl + Packer + Vault Agent module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── packer/
│       │   ├── rhel10.pkr.hcl
│       │   ├── scripts/
│       │   └── files/
│       └── USAGE.md
├── kubernetes/
│   └── basic/                    # Basic kubernetes provider module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tf
│       ├── data.tf
│       ├── locals.tf
│       └── USAGE.md
└── examples/
    ├── kubectl/
    │   ├── basic/                # kubectl basic example
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   ├── terraform.tfvars.example
    │   │   └── USAGE.md
    │   └── with-packer/          # kubectl + Packer example
    │       ├── main.tf
    │       ├── variables.tf
    │       ├── terraform.tfvars.example
    │       └── USAGE.md
    └── kubernetes/
        └── basic/                # kubernetes basic example
            ├── main.tf
            ├── variables.tf
            ├── terraform.tfvars.example
            └── USAGE.md
```

## Requirements

### Cluster Requirements

- Red Hat OpenShift cluster (ROSA, ARO, OCP on-prem, etc.)
- OpenShift Virtualization operator installed
- KubeVirt CRDs available in the cluster

### Terraform Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |

### Provider Requirements

#### kubectl Module
- kubectl provider >= 1.14.0
- kubernetes provider >= 2.23.0

#### kubernetes Module
- kubernetes provider >= 2.23.0

## Authentication

Both modules support two authentication methods:

### kubeconfig File
```hcl
kubeconfig_path = "~/.kube/config"
```

### Token Authentication
```hcl
cluster_host  = "https://api.cluster.example.com:6443"
cluster_token = var.openshift_token
```

## Features

- Support for multiple volume types:
  - containerDisk - Ephemeral container-based storage
  - dataVolume - CDI-managed persistent storage with HTTP/Registry sources
  - persistentVolumeClaim - Existing PVC reference
- Configurable CPU cores and memory
- Cloud-init support for VM initialization
- Custom labels and annotations
- Network configuration (model, interface)
- VM lifecycle management (start/stop/delete)
- Namespace validation

## Module Comparison

| Feature | kubernetes Module | kubectl Module |
|---------|------------------|----------------|
| State Management | ⚠️ Type validation workarounds | ✅ Clean |
| Drift Detection | ⚠️ May show inconsistencies | ✅ Accurate |
| Complex CRDs | ⚠️ Requires computed_fields | ✅ Native support |
| Resource Definition | HCL object | YAML string |
| Server-Side Apply | Limited | ✅ Full support |
| Production Ready | ⚠️ With workarounds | ✅ Yes |
| Recommended | No | **Yes** |

### Why kubectl Module is Recommended

The kubectl provider module offers several advantages:

- **Clean State Management**: No type validation errors or inconsistent state issues
- **Accurate Drift Detection**: Correctly identifies actual changes without false positives
- **Server-Side Apply**: Full support for Kubernetes server-side apply
- **YAML Native**: Works with raw YAML manifests, matching `kubectl apply` behavior
- **Better CRD Support**: Handles complex Custom Resource Definitions without workarounds

## Documentation

Comprehensive documentation is available for each module:

### Module Documentation
- [kubectl/basic Module](kubectl/basic/USAGE.md) - **Recommended**
- [kubectl/with-packer Module](kubectl/with-packer/USAGE.md) - Custom RHEL 10 + Vault Agent
- [kubernetes/basic Module](kubernetes/basic/USAGE.md)

### Example Documentation
- [kubectl/basic Example](examples/kubectl/basic/USAGE.md)
- [kubectl/with-packer Example](examples/kubectl/with-packer/USAGE.md)
- [kubernetes/basic Example](examples/kubernetes/basic/USAGE.md)

## Usage Examples

### Basic VM with containerDisk

```hcl
module "vm" {
  source = "./kubectl/basic"

  kubeconfig_path = "~/.kube/config"

  vm_name      = "fedora-vm"
  vm_namespace = "virtualization"

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

  vm_volume_type            = "dataVolume"
  vm_datavolume_source_http = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
  vm_datavolume_size        = "30Gi"
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

### VM with Custom RHEL 10 Image and Vault Agent

```hcl
module "vault_vm" {
  source = "./kubectl/with-packer"

  # Kubernetes authentication
  kubeconfig_path = "~/.kube/config"

  # Packer configuration - RHEL 10
  rhel10_image_url      = "https://access.redhat.com/downloads/rhel-10-kvm-guest-image.qcow2"
  rhel10_image_checksum = "sha256:abc123..."

  # Optional: RHEL subscription for updates during build
  rhel_subscription_username = var.rhel_username
  rhel_subscription_password = var.rhel_password

  # Vault configuration
  vault_version     = "1.15.0"
  vault_addr        = "https://vault.example.com:8200"
  vault_auth_method = "kubernetes"
  vault_role        = "my-app-role"

  # Vault secrets configuration
  vault_secrets_config = <<-EOT
    template {
      source      = "/etc/vault.d/templates/database.tpl"
      destination = "/etc/myapp/database.conf"
    }

    template {
      source      = "/etc/vault.d/templates/api-key.tpl"
      destination = "/etc/myapp/api-key.txt"
    }
  EOT

  # Container registry configuration
  registry_url      = "quay.io"
  registry_username = var.registry_username
  registry_password = var.registry_password
  image_name        = "myorg/rhel10-vault-agent"
  image_tag         = "v1.0.0"

  # VM configuration
  vm_name      = "vault-agent-vm"
  vm_namespace = "virtualization"
  vm_cpu_cores = 2
  vm_memory    = "4Gi"

  vm_labels = {
    environment = "production"
    managed-by  = "terraform"
    component   = "vault-agent"
  }
}
```

## Getting Started

1. Ensure OpenShift Virtualization is installed on your cluster:
   ```bash
   oc get csv -n openshift-cnv
   ```

2. Create a namespace for your VMs:
   ```bash
   oc create namespace virtualization
   ```

3. Copy one of the examples:
   ```bash
   cp -r examples/kubectl/basic my-vm-config
   cd my-vm-config
   ```

4. Configure your variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   ```

5. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

6. Verify the VM:
   ```bash
   oc get vm -n virtualization
   oc get vmi -n virtualization
   ```

## Outputs

Both modules provide the following outputs:

| Name | Description |
|------|-------------|
| vm_name | Name of the virtual machine |
| vm_namespace | Namespace of the virtual machine |
| vm_uid | UID of the virtual machine |
| vm_resource_version | Resource version of the virtual machine |
| vm_status | Status of the virtual machine |
| vm_object | Full virtual machine manifest |
