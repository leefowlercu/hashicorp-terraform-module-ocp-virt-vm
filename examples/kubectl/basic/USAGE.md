# Basic Example - kubectl Provider

This example demonstrates how to use the OpenShift Virtualization Terraform module with the `gavinbunney/kubectl` provider to create a KubeVirt VirtualMachine.

## Prerequisites

- Terraform >= 1.0
- Access to an OpenShift cluster with OpenShift Virtualization installed
- A namespace named `kubevirt-tf-module-test` (or modify `vm_namespace` in terraform.tfvars)
- Valid kubeconfig file or cluster credentials

## Quick Start

### 1. Configure Variables

Copy the example tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
kubeconfig_path = "~/.kube/config"

vm_name      = "test-vm"
vm_namespace = "kubevirt-tf-module-test"
vm_running   = true

vm_cpu_cores = 1
vm_memory    = "2Gi"

vm_volume_type     = "containerDisk"
vm_container_image = "quay.io/containerdisks/fedora:latest"
```

### 2. Verify Cluster Access

```bash
oc whoami
oc get namespace kubevirt-tf-module-test
```

If the namespace doesn't exist:

```bash
oc create namespace kubevirt-tf-module-test
```

### 3. Initialize Terraform

```bash
terraform init
```

This will download both the kubectl and kubernetes providers.

### 4. Plan and Apply

```bash
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

### 5. Verify the VM

```bash
oc get vm test-vm -n kubevirt-tf-module-test
oc get vmi test-vm -n kubevirt-tf-module-test
```

### 6. Verify No Drift

```bash
terraform plan -var-file terraform.tfvars
# Should show: No changes. Your infrastructure matches the configuration.
```

### 7. Clean Up

```bash
terraform destroy -var-file terraform.tfvars
```

## Advantages Over Kubernetes Provider

The kubectl provider version offers several improvements:

✅ **Clean Apply** - No type validation errors or state reconciliation issues
✅ **Drift Detection** - Accurate drift detection with no false positives
✅ **Server-Side Apply** - Better compatibility with Kubernetes admission controllers
✅ **YAML Native** - Works with raw YAML, same as `kubectl apply`
✅ **Simplified Outputs** - Direct access to resource attributes

## Authentication Methods

### Using Kubeconfig (Recommended for Development)

```hcl
kubeconfig_path = "~/.kube/config"
```

### Using Token and Host (Recommended for CI/CD)

Get your token:

```bash
oc whoami -t
```

Configure in terraform.tfvars:

```hcl
cluster_host  = "https://api.your-cluster.openshiftapps.com:6443"
cluster_token = "sha256~your-token-here"
```

## Configuration Options

### Volume Types

**containerDisk (Default):**
```hcl
vm_volume_type     = "containerDisk"
vm_container_image = "quay.io/containerdisks/fedora:latest"
```

**DataVolume with HTTP source:**
```hcl
vm_volume_type              = "dataVolume"
vm_datavolume_source_http   = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
vm_datavolume_size          = "30Gi"
vm_datavolume_storage_class = "gp3-csi"
```

**Existing PVC:**
```hcl
vm_volume_type = "persistentVolumeClaim"
vm_pvc_name    = "my-existing-pvc"
```

### Resource Configuration

```hcl
vm_cpu_cores = 2
vm_memory    = "4Gi"
vm_disk_bus  = "virtio"  # or "sata", "scsi"
```

### Cloud-Init User Data

```hcl
vm_cloudinit_userdata = <<-EOT
#cloud-config
users:
  - name: fedora
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAA...your-public-key
EOT
```

### Network Configuration

```hcl
vm_network_name           = "default"  # pod network
vm_network_interface_model = "virtio"   # or "e1000", "e1000e"
```

## Outputs

After a successful apply:

```hcl
vm_name      = "test-vm"
vm_namespace = "kubevirt-tf-module-test"
vm_uid       = "d9bbdcf8-ca09-4776-be0c-934aab8414ea"
vm_status    = null  # Status not exposed by kubectl provider
```

## Advanced Usage

### Using with Multiple VMs

Create multiple VMs using `for_each`:

```hcl
locals {
  vms = {
    web = {
      cpu_cores = 2
      memory    = "4Gi"
    }
    db = {
      cpu_cores = 4
      memory    = "8Gi"
    }
  }
}

module "vms" {
  for_each = local.vms
  source   = "../../../kubectl"

  kubeconfig_path = var.kubeconfig_path

  vm_name      = "${each.key}-vm"
  vm_namespace = "kubevirt-tf-module-test"

  vm_cpu_cores = each.value.cpu_cores
  vm_memory    = each.value.memory

  vm_volume_type     = "containerDisk"
  vm_container_image = "quay.io/containerdisks/fedora:latest"
}
```

### Custom Labels and Annotations

```hcl
vm_labels = {
  environment = "production"
  team        = "platform"
  managed-by  = "terraform"
}

vm_annotations = {
  "description"      = "Application server VM"
  "owner"            = "platform-team@example.com"
  "backup-policy"    = "daily"
}
```

## Provider Configuration

The kubectl provider supports the same authentication methods as the kubernetes provider:

```hcl
provider "kubectl" {
  config_path = "~/.kube/config"
  # OR
  host        = var.cluster_host
  token       = var.cluster_token
  insecure    = var.cluster_insecure
}
```

## Troubleshooting

**Namespace not found:**
```bash
oc create namespace kubevirt-tf-module-test
```

**OpenShift Virtualization not installed:**
- Contact your cluster administrator to install the OpenShift Virtualization operator

**VM creation failed:**
- Check VM events: `oc describe vm <vm-name> -n <namespace>`
- Check VMI status: `oc describe vmi <vm-name> -n <namespace>`
- Review virt-controller logs: `oc logs -n openshift-cnv -l kubevirt.io=virt-controller`

**Provider version issues:**
```bash
terraform init -upgrade
```

## Comparison with kubernetes Provider

| Feature | kubernetes Provider | kubectl Provider |
|---------|-------------------|------------------|
| State Management | ❌ Errors on apply | ✅ Clean |
| Drift Detection | ⚠️ Unreliable | ✅ Accurate |
| Complex CRDs | ❌ Type issues | ✅ Works well |
| YAML Support | Via HCL conversion | ✅ Native |
| Server-Side Apply | Limited | ✅ Full support |

**Recommendation:** Use the kubectl provider version for production deployments of KubeVirt VirtualMachines.
