# Basic Example - Kubernetes Provider

This example demonstrates how to use the OpenShift Virtualization Terraform module with the `hashicorp/kubernetes` provider to create a KubeVirt VirtualMachine.

## Prerequisites

- Terraform >= 1.0
- Access to an OpenShift cluster with OpenShift Virtualization installed
- A namespace for the VM (default: `default`)
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
vm_namespace = "default"
vm_running   = true

vm_cpu_cores = 1
vm_memory    = "2Gi"

# Use pre-installed OS image (recommended)
vm_volume_type                = "dataVolume"
vm_datavolume_source_ref_name = "fedora"
vm_datavolume_size            = "10Gi"
```

### 2. Verify Cluster Access

```bash
oc whoami
oc get datasource -n openshift-virtualization-os-images
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and Apply

```bash
terraform plan
terraform apply
```

### 5. Verify the VM

```bash
oc get vm test-vm
oc get vmi test-vm
```

### 6. Clean Up

```bash
terraform destroy
```

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

**DataVolume with sourceRef (Recommended):**

Uses pre-installed OS images from OpenShift Virtualization. Available DataSources include: `fedora`, `rhel9`, `rhel8`, `centos-stream9`, `centos-stream10`.

```hcl
vm_volume_type                = "dataVolume"
vm_datavolume_source_ref_name = "fedora"
vm_datavolume_size            = "10Gi"
```

**DataVolume with HTTP source:**

```hcl
vm_volume_type              = "dataVolume"
vm_datavolume_source_http   = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
vm_datavolume_size          = "30Gi"
vm_datavolume_storage_class = "gp3-csi"
```

**containerDisk (Ephemeral):**

```hcl
vm_volume_type     = "containerDisk"
vm_container_image = "quay.io/containerdisks/fedora:latest"
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

## Outputs

After a successful apply:

```hcl
vm_name      = "test-vm"
vm_namespace = "default"
vm_uid       = "abc123-..."
vm_status    = { ... }
```

## Known Limitations

**State Reconciliation Error:**

The kubernetes provider may show this error after creating resources:

```
Error: Provider produced inconsistent result after apply
```

**This is a cosmetic error.** The VM is created successfully despite this message. This is a known limitation of the `kubernetes_manifest` resource when handling complex CRDs like KubeVirt VirtualMachines.

### Workaround

If you encounter state issues:

1. The VM is created successfully - verify with `oc get vm`
2. Import the VM into state:

```bash
terraform import 'module.vm.kubernetes_manifest.virtual_machine' \
  "apiVersion=kubevirt.io/v1,kind=VirtualMachine,namespace=default,name=test-vm"
```

3. Continue managing with terraform plan/apply

## Troubleshooting

**Namespace not found:**

```bash
oc create namespace <your-namespace>
```

**DataSource not found:**

Verify OpenShift Virtualization OS images are available:

```bash
oc get datasource -n openshift-virtualization-os-images
```

**OpenShift Virtualization not installed:**

Contact your cluster administrator to install the OpenShift Virtualization operator.

**Timeout waiting for VM:**

- Check VM events: `oc describe vm <vm-name> -n <namespace>`
- Check VMI status: `oc describe vmi <vm-name> -n <namespace>`
