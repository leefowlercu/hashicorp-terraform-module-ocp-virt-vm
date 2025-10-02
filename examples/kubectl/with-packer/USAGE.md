# kubectl-with-packer Example

This example demonstrates deploying a KubeVirt VirtualMachine on OpenShift using a custom RHEL 10 image built by Packer with pre-installed HashiCorp Vault Agent.

## Overview

This example will:
1. Use Packer to build a custom RHEL 10 VM image with Vault Agent installed
2. Package the image as a containerDisk
3. Push the containerDisk to your container registry
4. Deploy a VM using the custom image
5. Configure Vault Agent at boot time via cloud-init

## Prerequisites

### Required Tools

- **Terraform** >= 1.0
- **Packer** >= 1.8.0
- **Docker** >= 20.0
- **kubectl** or **oc** CLI (for verification)

### Required Access

- OpenShift cluster with OpenShift Virtualization installed
- RHEL 10 KVM Guest Image (qcow2 format)
- Container registry account (Quay.io, Docker Hub, or private registry)
- Vault server with appropriate authentication configured

### Verify Prerequisites

```bash
# Check Terraform
terraform version

# Check Packer
packer version

# Check Docker
docker version

# Check OpenShift Virtualization
oc get csv -n openshift-cnv

# Verify namespace exists
oc get namespace kubevirt-tf-module-test || oc create namespace kubevirt-tf-module-test
```

## Quick Start

### 1. Obtain RHEL 10 Image

Download the RHEL 10 KVM Guest Image from:
- Red Hat Customer Portal: https://access.redhat.com/downloads/
- Internal mirror (if your organization maintains one)

Calculate the checksum:
```bash
shasum -a 256 rhel-10-kvm-guest-image.qcow2
```

### 2. Configure Variables

Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
# Kubernetes
kubeconfig_path = "~/.kube/config"

# RHEL 10 Image
rhel10_image_url      = "https://your-mirror.example.com/rhel-10-kvm.qcow2"
rhel10_image_checksum = "sha256:YOUR_ACTUAL_CHECKSUM_HERE"

# Optional: RHEL Subscription (for updates during build)
# rhel_subscription_username = "your-redhat-username"
# rhel_subscription_password = "your-redhat-password"

# Vault
vault_addr        = "https://vault.example.com:8200"
vault_role        = "my-app-role"

# Registry
registry_url      = "quay.io"
registry_username = "your-username"
registry_password = "your-password"
image_name        = "myorg/rhel10-vault-agent"
image_tag         = "v1.0.0"

# VM
vm_name      = "vault-agent-vm"
vm_namespace = "kubevirt-tf-module-test"
vm_cpu_cores = 2
vm_memory    = "4Gi"
```

### 3. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration (this will take 15-25 minutes for the first run)
terraform apply
```

### 4. Verify Deployment

```bash
# Check VM status
oc get vm vault-agent-vm -n kubevirt-tf-module-test

# Check VMI (running instance)
oc get vmi vault-agent-vm -n kubevirt-tf-module-test

# View VM details
oc describe vm vault-agent-vm -n kubevirt-tf-module-test

# Check Vault Agent inside VM (once VM is running)
oc rsh virt-launcher-vault-agent-vm-xxxxx
systemctl status vault-agent.service
journalctl -u vault-agent.service -n 50
```

## Configuration Options

### Packer Build Control

To skip the Packer build and use a pre-built image:

```hcl
packer_enabled = false
prebuilt_image = "quay.io/myorg/rhel10-vault-agent:v1.0.0"
```

### Vault Secrets Configuration

Configure Vault Agent to fetch and template secrets:

```hcl
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
```

You'll also need to create the template files in the image or via additional cloud-init configuration.

### Different Vault Auth Methods

#### AppRole Authentication

```hcl
vault_auth_method = "approle"

vm_additional_cloudinit_config = <<-EOT
write_files:
  - path: /etc/vault.d/role-id
    permissions: '0640'
    owner: vault:vault
    content: |
      your-role-id-here
  - path: /etc/vault.d/secret-id
    permissions: '0640'
    owner: vault:vault
    content: |
      your-secret-id-here
EOT
```

#### AWS Authentication

```hcl
vault_auth_method = "aws"
```

The AWS credentials will be automatically picked up from the EC2 instance metadata if running on AWS.

## Build Process Details

### What Happens During `terraform apply`

1. **Packer Build** (10-20 minutes)
   - Downloads RHEL 10 base image
   - Boots VM with QEMU
   - Optionally registers with RHSM
   - Updates packages
   - Downloads and installs Vault Agent
   - Configures systemd service
   - Unregisters from RHSM
   - Cleans cloud-init state
   - Outputs customized QCOW2 image

2. **Docker Build** (2-3 minutes)
   - Creates Dockerfile wrapping QCOW2
   - Builds containerDisk image
   - Tags with specified name and tag

3. **Registry Push** (1-2 minutes)
   - Authenticates to registry
   - Pushes containerDisk image

4. **VM Deployment** (1-2 minutes)
   - Creates VirtualMachine resource
   - References containerDisk from registry
   - Applies cloud-init configuration
   - VM boots and Vault Agent starts

### Monitoring Build Progress

Watch Terraform output for progress:
```bash
terraform apply 2>&1 | tee build.log
```

The build process will show:
- Packer initialization
- QEMU VM boot logs
- Package installation progress
- Docker build steps
- Registry push progress
- VM creation status

## Outputs

After successful deployment:

```bash
terraform output
```

Example outputs:
```
container_image = "quay.io/myorg/rhel10-vault-agent:v1.0.0"
full_image_reference = "quay.io/myorg/rhel10-vault-agent:v1.0.0"
vm_name = "vault-agent-vm"
vm_namespace = "kubevirt-tf-module-test"
vm_uid = "abc123-456-789-..."
```

## Troubleshooting

### Build Takes Too Long

Expected build time: 15-25 minutes

If it takes longer:
- Check network connectivity to RHEL image source
- Check network connectivity to registry
- Verify sufficient system resources (CPU, RAM, disk)

### Packer Build Fails

**Error: QEMU timeout**
- Increase `boot_wait` in packer template
- Check system virtualization support: `grep -E 'vmx|svm' /proc/cpuinfo`

**Error: Subscription registration failed**
- Verify RHEL credentials
- Or remove subscription variables to skip registration

**Error: Package installation failed**
- Check network connectivity
- Verify RHEL repository access

### Docker Build Fails

**Error: No space left on device**
- Clean Docker images: `docker system prune -a`
- Check available disk space: `df -h`

**Error: Permission denied**
- Ensure Docker daemon is running
- Verify user is in docker group: `sudo usermod -aG docker $USER`

### Registry Push Fails

**Error: Authentication failed**
- Verify registry credentials
- Test login: `docker login quay.io`

**Error: Unauthorized**
- Check repository exists and you have push access
- For Quay.io, repository must be created before first push

### VM Fails to Start

**Check VM events:**
```bash
oc describe vm vault-agent-vm -n kubevirt-tf-module-test
```

**Check VMI logs:**
```bash
oc logs virt-launcher-vault-agent-vm-xxxxx -n kubevirt-tf-module-test
```

**Common issues:**
- Container image not accessible from cluster
- Insufficient resources (CPU/memory)
- Image pull secrets not configured

### Vault Agent Not Starting

**Check cloud-init logs:**
```bash
oc rsh virt-launcher-vault-agent-vm-xxxxx
tail -f /var/log/cloud-init-output.log
```

**Check Vault Agent status:**
```bash
systemctl status vault-agent.service
journalctl -u vault-agent.service -n 100
```

**Common issues:**
- Vault server not reachable
- Incorrect vault_addr
- Authentication role not configured in Vault
- Kubernetes service account token missing

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

This will:
1. Delete the VirtualMachine
2. Leave the container image in the registry (manual cleanup required)
3. Leave Packer build artifacts in `packer/output/` (manual cleanup required)

To also clean up local artifacts:
```bash
rm -rf kubectl-with-packer/packer/output/
docker rmi quay.io/myorg/rhel10-vault-agent:v1.0.0
```

## Next Steps

- Customize the Packer template to install additional software
- Configure Vault policies for your application
- Set up Vault secret templates for your use case
- Deploy multiple VMs with different configurations
- Integrate with your CI/CD pipeline

## Additional Resources

- [Module Documentation](../../../kubectl/with-packer/USAGE.md)
- [Packer Documentation](https://developer.hashicorp.com/packer/docs)
- [Vault Agent Documentation](https://developer.hashicorp.com/vault/docs/agent-and-proxy/agent)
- [KubeVirt Documentation](https://kubevirt.io/user-guide/)
- [OpenShift Virtualization Documentation](https://docs.openshift.com/container-platform/latest/virt/about_virt/about-virt.html)
