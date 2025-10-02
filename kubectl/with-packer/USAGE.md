# kubectl-with-packer Module

Terraform module for managing KubeVirt VirtualMachines on OpenShift with custom RHEL 10 images built by Packer and pre-installed HashiCorp Vault Agent.

## Overview

This module extends the base `kubectl` module by integrating HashiCorp Packer to build custom RHEL 10 VM images with Vault Agent pre-installed. The workflow automates:

1. **Image Building** - Packer builds a RHEL 10 QCOW2 image with Vault Agent installed
2. **Containerization** - The QCOW2 image is wrapped as a containerDisk
3. **Registry Push** - The containerDisk is pushed to your container registry
4. **VM Deployment** - The VM is deployed using the custom image
5. **Runtime Configuration** - Vault Agent is configured via cloud-init at boot time

## Requirements

### Local Tools
| Tool | Version | Purpose |
|------|---------|---------|
| Packer | >= 1.8.0 | Build VM images |
| Docker | >= 20.0 | Build and push containerDisk images |
| Terraform | >= 1.0 | Infrastructure as code |

### Terraform Providers
| Name | Version |
|------|---------|
| kubectl | >= 1.14.0 |
| kubernetes | >= 2.23.0 |
| null | >= 3.0 |

### Cluster Requirements
- Red Hat OpenShift cluster with OpenShift Virtualization installed
- KubeVirt CRDs available
- Access to container registry (Quay.io, Docker Hub, or private registry)

### Image Requirements
- RHEL 10 KVM Guest Image (qcow2 format)
- Access to Red Hat Customer Portal or internal mirror

## Architecture

### Image Build Process

```
RHEL 10 qcow2 → Packer Build → Custom qcow2 → Docker Build → containerDisk → Registry Push
   (base)       (+ Vault Agent)   (customized)    (wrapped)      (stored)
```

### VM Boot Process

```
VM Created → cloud-init runs → Vault Agent configured → Vault Agent starts → Secrets fetched
```

## Module Usage

### Basic Usage

```hcl
module "vault_vm" {
  source = "path/to/kubectl-with-packer"

  # Kubernetes authentication
  kubeconfig_path = "~/.kube/config"

  # Packer configuration
  rhel10_image_url      = "https://access.redhat.com/downloads/rhel-10-kvm.qcow2"
  rhel10_image_checksum = "sha256:abc123..."

  # Vault configuration
  vault_addr        = "https://vault.example.com:8200"
  vault_auth_method = "kubernetes"
  vault_role        = "my-app-role"

  # Registry configuration
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
}
```

### With RHEL Subscription (for package updates during build)

```hcl
module "vault_vm" {
  source = "path/to/kubectl-with-packer"

  # ... other configuration ...

  rhel_subscription_username = var.rhel_username
  rhel_subscription_password = var.rhel_password
}
```

### With Vault Secrets Configuration

```hcl
module "vault_vm" {
  source = "path/to/kubectl-with-packer"

  # ... other configuration ...

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
}
```

### Using Pre-built Image (skip Packer build)

```hcl
module "vault_vm" {
  source = "path/to/kubectl-with-packer"

  packer_enabled = false
  prebuilt_image = "quay.io/myorg/rhel10-vault-agent:v1.0.0"

  # ... rest of configuration ...
}
```

## Variables

### Packer Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| packer_enabled | Enable Packer image build | bool | true | no |
| rhel10_image_url | URL to RHEL 10 KVM Guest Image | string | n/a | yes |
| rhel10_image_checksum | Checksum for RHEL 10 image | string | n/a | yes |
| rhel_subscription_username | RHEL subscription username | string | "" | no |
| rhel_subscription_password | RHEL subscription password | string | "" | no |
| packer_output_dir | Packer build output directory | string | "output" | no |

### Vault Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vault_version | Vault version to install | string | "1.15.0" | no |
| vault_addr | Vault server address | string | n/a | yes |
| vault_namespace | Vault namespace (Enterprise) | string | "" | no |
| vault_auth_method | Vault auth method | string | "kubernetes" | no |
| vault_role | Vault role name | string | n/a | yes |
| vault_secrets_config | Vault Agent template config | string | "" | no |

### Container Registry

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| registry_url | Container registry URL | string | "quay.io" | no |
| registry_username | Registry username | string | "" | no |
| registry_password | Registry password | string | "" | no |
| image_name | Container image name | string | n/a | yes |
| image_tag | Container image tag | string | "latest" | no |
| prebuilt_image | Pre-built image reference | string | "" | no |

### VM Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vm_name | VM name | string | n/a | yes |
| vm_namespace | VM namespace | string | "ocp-virt-tf-module-test" | no |
| vm_running | Desired running state | bool | true | no |
| vm_cpu_cores | Number of CPU cores | number | 2 | no |
| vm_memory | Memory allocation | string | "2Gi" | no |
| vm_disk_bus | Disk bus type | string | "virtio" | no |
| vm_network_interface_model | Network interface model | string | "virtio" | no |
| vm_labels | Labels for the VM | map(string) | {} | no |
| vm_annotations | Annotations for the VM | map(string) | {} | no |
| vm_termination_grace_period | Grace period in seconds | number | 30 | no |
| vm_additional_cloudinit_config | Additional cloud-init config | string | "" | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_name | Name of the virtual machine |
| vm_namespace | Namespace of the virtual machine |
| vm_uid | UID of the virtual machine |
| vm_resource_version | Resource version of the virtual machine |
| vm_status | Status of the virtual machine |
| vm_object | Full virtual machine manifest |
| container_image | Container image reference used |
| image_name | Name of the built container image |
| image_tag | Tag of the built container image |
| full_image_reference | Full container image reference |

## RHEL 10 Considerations

### Obtaining RHEL 10 Images

- **Red Hat Customer Portal**: Requires active subscription
- **Internal Mirror**: Many organizations maintain internal mirrors
- **Download Location**: https://access.redhat.com/downloads/

### Subscription Management

During the Packer build, if RHEL subscription credentials are provided:
1. System registers with Red Hat Subscription Manager (RHSM)
2. Packages are updated with `dnf update -y`
3. Vault Agent and dependencies are installed
4. System unregisters from RHSM (cleanup)

In production, VMs can authenticate using:
- Red Hat Satellite
- Activation keys
- Simple Content Access (SCA)

### Package Management

RHEL 10 uses DNF 4.x for package management. All package operations in the Packer template use `dnf` commands.

## Build Time

The complete build process typically takes **15-25 minutes**:

- Packer build: 10-20 minutes (depending on RHEL updates)
- Docker build: 2-3 minutes
- Registry push: 1-2 minutes (depending on image size and network)

## Workflow

### Initial Deployment

```bash
cd examples/kubectl/with-packer
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
terraform init
terraform plan   # Review the planned changes
terraform apply  # Build image and deploy VM
```

### Subsequent Deployments

If the image is already built and hasn't changed, Terraform will skip the Packer build and only update the VM configuration.

### Rebuilding Images

To force a rebuild:
- Change `vault_version`
- Change `image_tag`
- Modify Packer template files
- Use `terraform taint 'module.vault_vm.null_resource.packer_build[0]'`

## Troubleshooting

### Packer Build Failures

Check Packer logs in the Terraform output:
```bash
terraform apply 2>&1 | tee build.log
```

Common issues:
- RHEL image URL not accessible
- Checksum mismatch
- Subscription credentials invalid
- Insufficient disk space

### Docker Build Failures

Ensure Docker daemon is running:
```bash
docker info
```

Check available disk space:
```bash
df -h
```

### Registry Push Failures

Verify registry credentials:
```bash
docker login <registry-url>
```

Check network connectivity to registry.

### VM Boot Issues

Check cloud-init logs on the VM:
```bash
oc rsh virt-launcher-<vm-name>-xxxxx
tail -f /var/log/cloud-init-output.log
```

Check Vault Agent status:
```bash
systemctl status vault-agent.service
journalctl -u vault-agent.service -f
```

## Examples

See the [examples/kubectl/with-packer](../examples/kubectl/with-packer/) directory for a complete working example.

## Comparison with Base kubectl Module

| Feature | kubectl Module | kubectl-with-packer Module |
|---------|---------------|---------------------------|
| Base Image | Any containerDisk | Custom RHEL 10 |
| Vault Agent | Manual installation | Pre-installed |
| Build Process | None | Packer + Docker |
| Boot Time | Faster | Slightly slower (cloud-init) |
| Customization | Limited | Full control |
| Dependencies | None | Packer, Docker |

## Security Considerations

- RHEL subscription credentials are marked as sensitive
- Container registry credentials are marked as sensitive
- Vault Agent token stored securely in `/var/run/vault/token`
- VM image includes enterprise-grade RHEL 10 security features
- Clean cloud-init state before image creation

## License

This module follows the same license as the parent repository.
