# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Terraform modules for managing KubeVirt VirtualMachines on Red Hat OpenShift clusters with OpenShift Virtualization. It provides multiple module implementations using different Terraform providers and different VM image strategies.

## Module Architecture

### Module Organization

The repository implements modules organized by provider and functionality:

1. **kubectl/basic/** (Recommended) - Basic VM deployment with `gavinbunney/kubectl` provider
   - Handles manifests as YAML via `yamlencode()`
   - Uses `kubectl_manifest` resource with `server_side_apply = true`
   - Clean state management without type validation issues
   - Requires both kubectl and kubernetes providers (kubernetes provider is only needed for the `data.kubernetes_namespace` data source)

2. **kubectl/with-packer/** - Advanced VM deployment with Packer-built images and Vault Agent
   - Extends kubectl/basic with Packer integration
   - Builds custom RHEL 10 images with pre-installed Vault Agent
   - Uses `null_resource` to trigger Packer builds
   - Packages images as containerDisks and pushes to registry
   - Configures Vault Agent via cloud-init at boot time

3. **kubernetes/basic/** (Legacy) - Basic VM deployment with `hashicorp/kubernetes` provider
   - Handles manifests as HCL objects
   - Uses `kubernetes_manifest` resource
   - Requires extensive `computed_fields` to avoid type validation errors
   - Has known state reconciliation issues with complex CRDs

**Note**: The basic modules share a common core variable interface but have diverged in specific features. The kubernetes/basic module includes additional variables for DataVolume sourceRef support (`vm_datavolume_source_ref_name`, `vm_datavolume_source_ref_namespace`) while kubectl/basic includes `vm_network_name`. Switching between implementations may require variable adjustments.

### Manifest Construction Pattern

The basic modules follow similar logical architecture for building the VirtualMachine manifest, with key differences:

1. **locals.tf** constructs the complete KubeVirt VirtualMachine CRD manifest:
   - `root_volume` - Built conditionally based on `vm_volume_type` (containerDisk, dataVolume, or persistentVolumeClaim)
   - `cloudinit_volume` and `cloudinit_disk` - Optional, only created when `vm_cloudinit_userdata != null`
   - `all_volumes` and `all_disks` - Use `concat()` to combine required and optional elements
   - `datavolume_templates` - Only populated for dataVolume type
   - `vm_manifest` - Complete HCL object representing the VirtualMachine CRD
   - `vm_manifest_yaml` (kubectl only) - YAML conversion using `yamlencode()`

2. **main.tf** creates the resource using the constructed manifest

**Important Patterns**:
- Use `concat()` instead of `compact()` when building lists of objects. The `compact()` function only works with string lists, not object lists.
- **kubernetes/basic uses `jsondecode(jsonencode(...))` wrapper** for `root_volume` to bypass Terraform's type checking when conditional branches return objects with different structures (containerDisk vs dataVolume vs persistentVolumeClaim keys).

#### Module-Specific Differences in locals.tf

| Feature | kubectl/basic | kubernetes/basic |
|---------|--------------|------------------|
| root_volume | Direct ternary | `jsondecode(jsonencode(...))` wrapper |
| datavolume_templates | HTTP source only | HTTP source + sourceRef via `merge()` |
| Validation local | None | `_validate_datavolume_source` |
| Namespace data source | `kubernetes_namespace` | `kubernetes_namespace_v1` |

### Volume Type System

The modules support three volume types via `vm_volume_type`:

- **containerDisk**: Ephemeral storage using container images from registries (e.g., quay.io/containerdisks/fedora:latest)
- **dataVolume**: Persistent storage with CDI integration, creates PVC automatically
  - kubectl/basic: Supports HTTP source only (`vm_datavolume_source_http`)
  - kubernetes/basic: Supports HTTP source OR sourceRef for pre-installed OS images (`vm_datavolume_source_ref_name`)
- **persistentVolumeClaim**: Reference to existing PVC created outside the module

Each volume type has its own conditional branch in `locals.tf:root_volume` and corresponding required variables.

#### DataVolume sourceRef (kubernetes/basic only)

The kubernetes/basic module supports referencing pre-installed OS images via DataSource:

```hcl
vm_volume_type                   = "dataVolume"
vm_datavolume_source_ref_name    = "fedora"  # or rhel9, rhel8, centos-stream9, centos-stream10
vm_datavolume_source_ref_namespace = "openshift-virtualization-os-images"
vm_datavolume_size               = "35Gi"
```

The module includes validation that requires either `vm_datavolume_source_http` or `vm_datavolume_source_ref_name` when using dataVolume type.

## Commands

### Testing Modules

When testing either module, use the examples directories:

```bash
# Test kubectl module
cd examples/kubectl/basic
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with actual values
terraform init
terraform plan
terraform apply
```

```bash
# Test kubernetes module
cd examples/kubernetes/basic
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with actual values
terraform init
terraform plan
terraform apply
```

### Verify VMs on OpenShift

```bash
# Check VirtualMachine resources
oc get vm -n <namespace>

# Check VirtualMachineInstance resources (running VMs)
oc get vmi -n <namespace>

# Get detailed VM information
oc describe vm <vm-name> -n <namespace>
```

### Format Terraform Code

```bash
terraform fmt -recursive
```

## Development Guidelines

### When Making Changes to Basic Module Logic

The basic modules have diverged in specific features. When modifying shared logic:

1. **Core VM functionality** (CPU, memory, lifecycle, cloud-init) should remain consistent across both modules
2. **Module-specific features** may differ:
   - kubectl/basic: Simpler implementation, HTTP-only dataVolume source
   - kubernetes/basic: sourceRef support, validation locals, `jsondecode/jsonencode` wrappers
3. **Key differences to maintain**:
   - kubectl/basic: `vm_manifest_yaml = yamlencode(local.vm_manifest)` for YAML output
   - kubernetes/basic: `jsondecode(jsonencode(...))` wrapper for root_volume type safety
   - kubernetes/basic: `_validate_datavolume_source` validation local
   - kubernetes/basic: `merge()` pattern in datavolume_templates for sourceRef support
4. When adding features to both modules, consider if the feature requires type workarounds in kubernetes/basic

### When Making Changes to kubectl/with-packer Module

The kubectl/with-packer module is independent and does not need to maintain parity with other modules. Changes to this module may include:

1. Packer template updates in `packer/rhel10.pkr.hcl`
2. Vault Agent installation script changes in `packer/scripts/install-vault-agent.sh`
3. Build orchestration updates in `scripts/build-and-push.sh`
4. Cloud-init template modifications in `templates/vault-agent-cloudinit.yaml.tftpl`
5. Additional variables for Packer, Vault, or registry configuration

### When Adding New Features to Basic Modules

If adding new VM configuration options to basic modules (e.g., additional volume types, network configurations):

1. Add variables to both `kubectl/basic/variables.tf` and `kubernetes/basic/variables.tf`
2. Update locals logic in both `kubectl/basic/locals.tf` and `kubernetes/basic/locals.tf`
3. Update both example configurations in `examples/kubectl/basic/` and `examples/kubernetes/basic/`
4. Document the feature in both `kubectl/basic/USAGE.md` and `kubernetes/basic/USAGE.md`
5. Update the main `README.md`
6. Consider if the feature should also be added to `kubectl/with-packer/`

### Known Issue: kubernetes_manifest State Reconciliation

The `kubernetes/basic/` module has a known, unfixable issue with the `kubernetes_manifest` resource producing "Provider produced inconsistent result after apply" errors. This is a fundamental limitation of how the kubernetes provider validates complex CRD schemas.

#### Testing Results (December 2025)

Comprehensive testing against a live OpenShift cluster confirmed this error **cannot be resolved**:

- ❌ Provider version upgrade (`~> 3.0.1`)
- ❌ Simplified `computed_fields` with best practices pattern
- ❌ Extended `computed_fields` covering 40+ nested paths
- ❌ Various `force_conflicts` and `lifecycle` configurations
- ❌ `jsondecode/jsonencode` wrapper for type safety (helps with plan, not apply)
- ✅ kubectl provider works perfectly with identical VM manifest

#### Root Cause

The issue occurs because:
1. The kubernetes provider uses HCL-to-CRD type validation
2. The Kubernetes API server enriches resources with defaults and type conversions (e.g., `{}` becomes `null`, adds `machine.type`)
3. The provider cannot reconcile these API server enrichments with the original HCL structure

**Do not attempt to fix this by**:
- Adding more `computed_fields` (tested, does not work)
- Changing manifest structure (does not work)
- Using `wait` conditions (causes additional issues)
- Upgrading provider version (tested with latest, does not work)

**The kubectl/basic module exists specifically as the solution to this issue.** It uses YAML-based manifests via `yamlencode()` and Server-Side Apply without HCL type validation.

### Working with KubeVirt CRDs

Important concepts when working with VirtualMachine manifests:

- **VirtualMachine vs VirtualMachineInstance**: VM is the stateful resource with lifecycle management (spec.running), VMI is the ephemeral running instance
- **spec.running vs spec.runStrategy**: This module uses `spec.running` for simple start/stop control
- **dataVolumeTemplates**: Inline DataVolume definitions that are part of the VM spec, created automatically with the VM
- **Cloud-init**: Uses `cloudInitNoCloud` volume type with `userData` field containing cloud-config YAML

### Authentication Configuration

Both modules support two authentication patterns via provider configuration:

1. **kubeconfig**: Set `kubeconfig_path` variable
2. **Token**: Set both `cluster_host` and `cluster_token` variables

The provider configuration is defined in each module's `providers.tf` and uses these variables directly.

### Testing Against ROSA

When testing with Red Hat OpenShift Service on AWS (ROSA):

1. Ensure OpenShift Virtualization operator is installed: `oc get csv -n openshift-cnv`
2. Create test namespace: `oc create namespace <namespace-name>`
3. Use appropriate storage class (e.g., `gp3-csi` for AWS EBS) when using dataVolume type
4. Token can be obtained from ROSA console or via `oc whoami -t`

## File Organization Standards

This project follows standard Terraform module structure:

- `terraform.tf` - Provider requirements and Terraform version constraints
- `providers.tf` - Provider configuration blocks
- `variables.tf` - Input variable definitions
- `data.tf` - Data source definitions (namespace lookup)
- `locals.tf` - Local value computations (manifest construction)
- `main.tf` - Resource definitions
- `outputs.tf` - Output value definitions

Examples follow the same structure with the addition of `terraform.tfvars.example` templates.
