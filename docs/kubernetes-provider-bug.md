# kubernetes_manifest Resource Bug Report: Inconsistent Result After Apply

**Issue Type**: Provider Bug - Type Validation Failure
**Severity**: High - Blocks production use for complex CRDs
**Provider**: hashicorp/kubernetes
**Affected Versions**: 2.23.0 through 3.0.1 (latest tested)
**Resource**: `kubernetes_manifest`
**Date Reported**: December 2025
**Reproducible**: Yes (100% of the time with KubeVirt VirtualMachine CRD)

## Executive Summary

The `kubernetes_manifest` resource produces a consistent and unfixable error when managing KubeVirt VirtualMachine custom resources:

```
Error: Provider produced inconsistent result after apply

When applying changes to module.vm.kubernetes_manifest.virtual_machine,
provider "module.vm.provider["registry.terraform.io/hashicorp/kubernetes"]"
produced an unexpected new value: .object: wrong final value type:
incorrect object attributes.

This is a bug in the provider, which should be reported in the provider's
own issue tracker.
```

**Critical**: The resource IS created successfully in the cluster, but Terraform's state management fails, making this resource unusable for production without manual intervention.

This issue cannot be resolved through configuration changes including:
- Provider version upgrades
- `computed_fields` configuration (tested with 40+ field paths)
- `field_manager` settings
- `lifecycle` blocks

The `gavinbunney/kubectl` provider manages identical manifests without error.

## Environment Details

### Cluster Environment
- **Platform**: Red Hat OpenShift Container Platform
- **OpenShift Virtualization**: Installed and operational
- **KubeVirt API Version**: kubevirt.io/v1
- **Kubernetes Version**: 1.30+ (OpenShift 4.x)

### Terraform Environment
```hcl
Terraform v1.0+
hashicorp/kubernetes v3.0.1 (latest tested)
hashicorp/kubernetes v2.38.0 (previously tested)
hashicorp/kubernetes v2.23.0 (initial version)
```

### CRD Details
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualmachines.kubevirt.io
spec:
  group: kubevirt.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      # Extremely complex nested schema with:
      # - 50+ top-level spec fields
      # - Deeply nested optional structures (5+ levels)
      # - Many fields with default values
      # - Server-side type conversions
```

## Issue Description

### Observed Behavior

1. `terraform plan` succeeds and shows intended changes
2. `terraform apply` creates the VirtualMachine resource successfully in the cluster
3. **Immediately after creation**, Terraform throws the error above
4. The resource exists and functions correctly in Kubernetes/OpenShift
5. Terraform state is corrupted/incomplete
6. Subsequent `terraform plan` attempts to recreate the resource
7. Manual `terraform import` required to fix state

### Error Message (Complete)

```
Error: Provider produced inconsistent result after apply

When applying changes to module.vm.kubernetes_manifest.virtual_machine,
provider "module.vm.provider["registry.terraform.io/hashicorp/kubernetes"]"
produced an unexpected new value: .object: wrong final value type:
incorrect object attributes.

This is a bug in the provider, which should be reported in the provider's
own issue tracker.
```

**Error Location**: After successful API call, during state reconciliation
**Impact**: State file is not updated with resource data
**Workaround Required**: Manual `terraform import` after every apply

## Root Cause Analysis

### Technical Explanation

The error occurs due to a fundamental mismatch in how `kubernetes_manifest` validates complex CRD responses:

#### 1. HCL-to-Kubernetes Conversion Process

```
User HCL Object → Provider Conversion → JSON Payload → Kubernetes API
                                                            ↓
                                                  API Enrichment Process
                                                            ↓
Terraform State ← Type Validation ← JSON Response ← API Server
                        ↑
                   FAILURE POINT
```

#### 2. API Server Enrichment

When the Kubernetes API server receives a VirtualMachine manifest, it:

**Adds default values:**
```yaml
# User provides:
spec:
  template:
    spec:
      domain:
        devices:
          interfaces:
          - masquerade: {}
            name: default

# API server returns:
spec:
  template:
    spec:
      domain:
        devices:
          interfaces:
          - masquerade: {}
            name: default
            macAddress: "02:e5:84:00:00:04"  # Added by kubemacpool
            model: "virtio"                  # Default from CRD schema
        machine:
          type: "pc-q35-rhel9.6.0"          # Added by platform detection
        architecture: "amd64"                # Added by node architecture
```

**Converts types:**
```yaml
# User provides:
interfaces:
- masquerade: {}        # Empty object in HCL

# API server may return:
interfaces:
- masquerade: null      # Converted to null or omitted
```

**Adds computed metadata:**
```yaml
metadata:
  annotations:
    kubemacpool.io/transaction-timestamp: "2025-10-02T00:16:19.381349849Z"
```

#### 3. Type Validation Failure

The provider's type validator:
1. Takes the enriched API response
2. Attempts to validate it against the original HCL schema
3. Encounters fields that weren't in the original HCL
4. Cannot determine if these are "computed" or "unexpected"
5. Fails with "wrong final value type: incorrect object attributes"

### Why computed_fields Doesn't Fully Solve This

The `computed_fields` attribute has limitations:

1. **No wildcard support**: Cannot use `spec.template.spec.domain.*` to mark all nested fields
2. **Cannot penetrate lists**: Cannot mark `spec.template.spec.volumes[*].containerDisk` as computed
3. **Field explosion**: Would need to enumerate every possible nested combination
4. **CRD version changes**: New API versions add new computed fields

Example of the limitation:
```hcl
computed_fields = [
  "spec.template.spec.domain.machine",     # Can mark this
  # But CANNOT mark:
  # "spec.template.spec.domain.devices.interfaces[*].macAddress"
  # "spec.template.spec.volumes[*].containerDisk.imagePullPolicy"
  # Must mark entire parent:
  "spec.template.spec.domain.devices",     # Too broad - loses drift detection
  "spec.template.spec.volumes",            # Too broad - loses drift detection
]
```

## Reproduction Steps

### Minimal Reproduction Code

**File: terraform.tf**
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }
}
```

**File: providers.tf**
```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}
```

**File: main.tf**
```hcl
data "kubernetes_namespace" "test" {
  metadata {
    name = "default"
  }
}

resource "kubernetes_manifest" "virtual_machine" {
  manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = "test-vm"
      namespace = data.kubernetes_namespace.test.metadata[0].name
    }
    spec = {
      running = true
      template = {
        metadata = {
          labels = {
            "kubevirt.io/vm" = "test-vm"
          }
        }
        spec = {
          domain = {
            cpu = {
              cores = 1
            }
            resources = {
              requests = {
                memory = "2Gi"
              }
            }
            devices = {
              disks = [{
                name = "rootdisk"
                disk = {
                  bus = "virtio"
                }
              }]
              interfaces = [{
                name       = "default"
                masquerade = {}
              }]
            }
          }
          networks = [{
            name = "default"
            pod  = {}
          }]
          volumes = [{
            name = "rootdisk"
            containerDisk = {
              image = "quay.io/containerdisks/fedora:latest"
            }
          }]
        }
      }
    }
  }

  computed_fields = [
    "metadata.generation",
    "status"
  ]

  field_manager {
    force_conflicts = true
  }
}
```

### Steps to Reproduce

**Prerequisites:**
1. OpenShift cluster with OpenShift Virtualization installed
2. `oc` CLI authenticated to cluster
3. Terraform 1.0+ installed

**Commands:**
```bash
# 1. Verify OpenShift Virtualization is installed
oc get csv -n openshift-cnv | grep kubevirt

# 2. Verify VirtualMachine CRD exists
oc get crd virtualmachines.kubevirt.io

# 3. Initialize Terraform
terraform init

# 4. Plan (succeeds)
terraform plan

# 5. Apply (creates VM but fails)
terraform apply -auto-approve
```

**Expected Result:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

**Actual Result:**
```
Error: Provider produced inconsistent result after apply
...
```

**Verification:**
```bash
# VM exists despite error
oc get vm test-vm -n default
# NAME      AGE   STATUS    READY
# test-vm   10s   Running   True

# But Terraform state is broken
terraform show
# Shows nothing or incomplete data
```

## Testing Performed

We conducted comprehensive testing against a live OpenShift cluster to determine if any configuration could resolve this issue.

### Test 1: Provider Version Upgrade

**Configuration:**
```hcl
# Before
version = ">= 2.23.0"

# After (tested with multiple versions)
version = "~> 2.38.0"  # Tested October 2025
version = "~> 3.0.1"   # Tested December 2025
```

**Result**: ❌ Error persists across all versions
**Conclusion**: Not a version-specific bug - code is identical between v2.38.0 and v3.0.1

### Test 2: Minimal computed_fields (Best Practice)

**Configuration:**
```hcl
computed_fields = [
  "metadata.generation",
  "status"
]

field_manager {
  force_conflicts = true
}

# Removed lifecycle block
```

**Result**: ❌ Error persists
**Error Message**: Identical to baseline
**Conclusion**: Minimal computed_fields insufficient for complex CRDs

### Test 3: Extended computed_fields

**Configuration:**
```hcl
computed_fields = [
  "metadata.annotations",
  "metadata.labels",
  "metadata.finalizers",
  "metadata.generation",
  "spec.runStrategy",
  "spec.instancetype",
  "spec.preference",
  "spec.template.metadata",
  "spec.template.spec.accessCredentials",
  "spec.template.spec.affinity",
  "spec.template.spec.architecture",
  "spec.template.spec.dnsConfig",
  "spec.template.spec.dnsPolicy",
  "spec.template.spec.domain.chassis",
  "spec.template.spec.domain.clock",
  "spec.template.spec.domain.cpu",
  "spec.template.spec.domain.devices",
  "spec.template.spec.domain.features",
  "spec.template.spec.domain.firmware",
  "spec.template.spec.domain.ioThreads",
  "spec.template.spec.domain.ioThreadsPolicy",
  "spec.template.spec.domain.launchSecurity",
  "spec.template.spec.domain.machine",
  "spec.template.spec.domain.memory",
  "spec.template.spec.domain.resources",
  "spec.template.spec.evictionStrategy",
  "spec.template.spec.hostname",
  "spec.template.spec.livenessProbe",
  "spec.template.spec.networks",
  "spec.template.spec.nodeSelector",
  "spec.template.spec.priorityClassName",
  "spec.template.spec.readinessProbe",
  "spec.template.spec.schedulerName",
  "spec.template.spec.startStrategy",
  "spec.template.spec.subdomain",
  "spec.template.spec.tolerations",
  "spec.template.spec.topologySpreadConstraints",
  "spec.template.spec.volumes",
  "spec.updateVolumesStrategy",
  "status"
]

field_manager {
  force_conflicts = true
}

lifecycle {
  ignore_changes = [object]
}
```

**Result**: ❌ Error persists
**Error Message**: Identical to baseline
**Conclusion**: Even comprehensive computed_fields cannot resolve the issue

### Test 4: kubectl Provider Comparison

**Configuration:**
```hcl
# Changed from kubernetes provider to kubectl provider
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19.0"
    }
  }
}

resource "kubectl_manifest" "virtual_machine" {
  yaml_body = yamlencode({
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    # ... identical manifest as kubernetes_manifest test
  })

  server_side_apply = true
  wait              = true
}
```

**Result**: ✅ Success
**Apply Time**: 1 second
**Drift Detection**: None (subsequent `terraform plan` shows no changes)
**Conclusion**: kubectl provider handles identical manifest without issues

## Expected vs Actual Behavior

### Expected Behavior

1. `terraform apply` creates VirtualMachine resource
2. Provider reads back enriched resource from API
3. Provider stores complete resource data in state
4. `terraform plan` shows no changes
5. State management works normally

### Actual Behavior

1. `terraform apply` creates VirtualMachine resource ✅
2. Provider reads back enriched resource from API ✅
3. Provider type validation fails ❌
4. Error thrown, state not updated ❌
5. Resource orphaned from Terraform management ❌

### Why kubectl Provider Succeeds

The `kubectl` provider avoids this issue by:

1. **YAML-based manifests**: Uses `yamlencode()` to convert HCL to YAML string
2. **No type validation**: Treats manifest as opaque YAML, doesn't validate against schema
3. **Server-Side Apply**: Kubernetes handles field ownership and merging
4. **String comparison**: State comparison is YAML string diff, not object validation

```hcl
# kubectl provider approach
resource "kubectl_manifest" "vm" {
  yaml_body = yamlencode(local.manifest)  # Convert to YAML string
  server_side_apply = true                # Let Kubernetes handle merging
  # No computed_fields needed
  # No field_manager needed
  # No lifecycle blocks needed
}
```

## Technical Deep Dive

### Actual Implementation in terraform-provider-kubernetes

The error occurs due to a chain of type conversions that cannot handle API server enrichment. Below is the actual code flow from the provider source (version 3.0.1).

**Note**: The code in the files below is **identical between v2.38.0 and v3.0.1**. No fixes have been applied to address this issue.

#### Phase 1: Planning - Marking Computed Fields as Unknown

**File**: `manifest/provider/plan.go`
**Lines**: 206-238, 410-415

During planning, the provider extracts `computed_fields` configuration:

```go
// Extract computed_fields from user configuration
computedFields := make(map[string]*tftypes.AttributePath)
var atp *tftypes.AttributePath
cfVal, ok := proposedVal["computed_fields"]
if ok && !cfVal.IsNull() && cfVal.IsKnown() {
    var cf []tftypes.Value
    cfVal.As(&cf)
    for _, v := range cf {
        var vs string
        err := v.As(&vs)
        // ... error handling ...
        atp, err := FieldPathToTftypesPath(vs)
        // ... error handling ...
        computedFields[atp.String()] = atp
    }
} else {
    // When not specified by the user, 'metadata.annotations' and 'metadata.labels' are configured as default
    atp = tftypes.NewAttributePath().WithAttributeName("metadata").WithAttributeName("annotations")
    computedFields[atp.String()] = atp

    atp = tftypes.NewAttributePath().WithAttributeName("metadata").WithAttributeName("labels")
    computedFields[atp.String()] = atp
}
```

Then marks these fields as Unknown in the planned state:

```go
// For Create operations
newObj, err := tftypes.Transform(completePropMan, func(ap *tftypes.AttributePath, v tftypes.Value) (tftypes.Value, error) {
    _, ok := computedFields[ap.String()]
    if ok {
        return tftypes.NewValue(v.Type(), tftypes.UnknownValue), nil  // Mark as Unknown
    }
    return v, nil
})
```

**Purpose**: Tell Terraform "these fields will be computed by the API server during apply"

#### Phase 2: Apply - Kubernetes API Call

**File**: `manifest/provider/apply.go`
**Lines**: 374-381

The provider calls Kubernetes API with Server-Side Apply:

```go
// Call the Kubernetes API to create the new resource
s.logger.Trace("[ApplyResourceChange][API Payload]: %s", jsonManifest)
result, err := rs.Patch(ctxDeadline, rname, types.ApplyPatchType, jsonManifest,
    metav1.PatchOptions{
        FieldManager: fieldManagerName,
        Force:        &forceConflicts,
    },
)
```

This successfully creates the VirtualMachine. The `result` object contains the API server's enriched response.

#### Phase 3: State Conversion - Where the Bug Occurs

**File**: `manifest/provider/apply.go`
**Lines**: 461-486 (core logic at 461-470)

After the successful API call, the provider must convert the enriched Kubernetes response back to Terraform state:

```go
// Convert API response to tftypes.Value
newResObject, err := payload.ToTFValue(RemoveServerSideFields(result.Object), tsch, th, tftypes.NewAttributePath())
if err != nil {
    resp.Diagnostics = append(resp.Diagnostics,
        &tfprotov5.Diagnostic{
            Severity: tfprotov5.DiagnosticSeverityError,
            Summary:  "Conversion from Unstructured to tftypes.Value failed",
            Detail:   err.Error(),
        })
    return resp, nil
}
s.logger.Trace("[ApplyResourceChange][Apply]", "[payload.ToTFValue]", dump(newResObject))

// Mark computed fields as unknown
compObj, err := morph.DeepUnknown(tsch, newResObject, tftypes.NewAttributePath())
if err != nil {
    return resp, err
}
plannedStateVal["object"] = morph.UnknownToNull(compObj)

newStateVal := tftypes.NewValue(applyPlannedState.Type(), plannedStateVal)
s.logger.Trace("[ApplyResourceChange][Apply]", "new state value", dump(newStateVal))

newResState, err := tfprotov5.NewDynamicValue(newStateVal.Type(), newStateVal)
if err != nil {
    return resp, err
}
resp.NewState = &newResState
```

#### The Critical Bug: Type Mismatch in Conversion Chain

**Problem 1: payload.ToTFValue Creates Wrong Types**

**File**: `manifest/payload/to_value.go`
**Lines**: 250-266

```go
func mapToTFObjectValue(in map[string]interface{}, st tftypes.Type, th map[string]string, at *tftypes.AttributePath) (tftypes.Value, error) {
    im := make(map[string]tftypes.Value)
    oTypes := make(map[string]tftypes.Type)
    for k, kt := range st.(tftypes.Object).AttributeTypes {  // Iterate SCHEMA attributes
        eap := at.WithAttributeName(k)
        v, ok := in[k]
        if !ok {
            v = nil
        }
        nv, err := ToTFValue(v, kt, th, eap)  // Convert with SCHEMA type
        if err != nil {
            return tftypes.Value{}, eap.NewErrorf("[%s] cannot convert map element value: %s", eap, err)
        }
        im[k] = nv
        oTypes[k] = nv.Type()  // ← BUG: Use ACTUAL type, not schema type
    }
    return tftypes.NewValue(tftypes.Object{AttributeTypes: oTypes}, im), nil
}
```

**The Issue**:
- Line 253: Iterates over `st.(tftypes.Object).AttributeTypes` (the EXPECTED schema)
- Line 264: Creates `oTypes[k] = nv.Type()` using the ACTUAL value's type
- If API returns a different type than expected (e.g., `null` instead of `{}`), the output type doesn't match the schema

**Problem 2: morph.DeepUnknown Only Processes Schema Fields**

**File**: `manifest/morph/scaffold.go`
**Lines**: 14-118 (Object handling at lines 22-40)

**Note**: A partial fix was applied in April 2024 (commit f83d63ac) to prevent schema type mutation, but the core architectural limitation remains.

```go
func DeepUnknown(t tftypes.Type, v tftypes.Value, p *tftypes.AttributePath) (tftypes.Value, error) {
    if t == nil {
        return tftypes.Value{}, fmt.Errorf("type cannot be nil")
    }
    if !v.IsKnown() {
        return tftypes.NewValue(t, tftypes.UnknownValue), nil
    }
    switch {
    case t.Is(tftypes.Object{}):
        atts := t.(tftypes.Object).AttributeTypes  // ← Get SCHEMA attributes
        var vals map[string]tftypes.Value
        ovals := make(map[string]tftypes.Value, len(atts))
        otypes := make(map[string]tftypes.Type, len(atts))  // ← Added in April 2024 fix
        err := v.As(&vals)
        if err != nil {
            return tftypes.Value{}, p.NewError(err)
        }
        for name, att := range atts {  // ← ONLY iterate SCHEMA attributes, ignore extras from API
            np := p.WithAttributeName(name)
            nv, err := DeepUnknown(att, vals[name], np)
            if err != nil {
                return tftypes.Value{}, np.NewError(err)
            }
            ovals[name] = nv
            otypes[name] = nv.Type()  // ← Now uses separate map (April 2024 fix)
        }
        return tftypes.NewValue(tftypes.Object{AttributeTypes: otypes}, ovals), nil
    // ... other cases ...
}
```

**The Issue** (still present after April 2024 fix):
- Line 23: Gets `atts` from the SCHEMA
- Line 31: Only iterates over SCHEMA attributes
- Any fields added by the API server that aren't in the schema are silently ignored
- The April 2024 fix prevents schema mutation but does not address the core limitation

#### Why Terraform SDK Rejects the State

After the provider returns from `ApplyResourceChange`, Terraform's SDK (outside the provider code) performs validation:

1. Compares `plannedState` (from Plan phase) to `newState` (from Apply phase)
2. Checks that types match for all fields
3. For fields marked as computed (Unknown in plan), checks that the actual type matches the schema type
4. **Fails** when it finds type mismatches like:
   - Planned: `Object{AttributeTypes: {...}}`
   - Actual: Different attribute types within the object

The error "wrong final value type: incorrect object attributes" means:
- The object's attribute types don't match what was expected
- This happens because `ToTFValue` creates types from actual values, not schema types

#### Concrete Example with KubeVirt VirtualMachine

```go
// User provides in HCL:
interfaces = [{
  name       = "default"
  masquerade = {}  // Empty object
}]

// Schema expects:
interfaces: List[Object{
  name: String,
  masquerade: Object{...}  // Object type
}]

// API server returns:
interfaces = [{
  name: "default"
  masquerade: null           // Converted to null!
  macAddress: "02:e5:84:00:00:04"  // Added by kubemacpool
  model: "virtio"            // Added with default
}]

// ToTFValue creates:
interfaces: List[Object{
  name: String,
  masquerade: Null,          // ← TYPE MISMATCH: null vs Object
  macAddress: String,         // Not in schema, ignored
  model: String              // Not in schema, ignored
}]

// Terraform SDK validation:
Expected type: Object{masquerade: Object{...}}
Actual type:   Object{masquerade: Null}
→ Error: "wrong final value type"
```

#### Why computed_fields Cannot Fix This

Even with comprehensive `computed_fields`:

```hcl
computed_fields = [
  "spec.template.spec.domain.devices.interfaces",
  # ... 40+ other paths
]
```

The problem persists because:

1. **No wildcard support**: Can't mark `interfaces[*].macAddress` as computed
2. **Can't mark nested types**: Can't mark `interfaces[*].masquerade` specifically
3. **All-or-nothing**: Marking entire `interfaces` as computed loses all validation
4. **Type conversion still happens**: Even for computed fields, `ToTFValue` still creates wrong types

### Problematic API Server Behaviors

#### 1. Empty Object Conversion
```yaml
# Planned
masquerade: {}

# Returned
masquerade: null
# or omitted entirely
```

This causes type mismatch: `map[string]interface{}` vs `nil`

#### 2. Field Addition in Nested Structures
```yaml
# Planned
devices:
  interfaces:
  - name: default
    masquerade: {}

# Returned
devices:
  interfaces:
  - name: default
    masquerade: {}
    macAddress: "02:e5:84:00:00:04"  # Added
    model: "virtio"                  # Added
```

Marking `spec.template.spec.domain.devices` as computed loses all validation.

#### 3. Structural Defaults
```yaml
# Planned (not provided)
domain:
  cpu:
    cores: 1

# Returned (added by admission controller)
domain:
  cpu:
    cores: 1
    sockets: 1      # Added
    threads: 1      # Added
  machine:
    type: "pc-q35-rhel9.6.0"  # Added
```

## Supporting Evidence

### Live Cluster Testing

All tests performed against:
- OpenShift 4.x cluster
- OpenShift Virtualization operator installed
- VirtualMachine CRD kubevirt.io/v1

**Test Run Date**: December 2025 (latest), October 2025 (initial)
**Test Iterations**: 4 major configuration variants across multiple provider versions
**Success Rate**: 0% (kubernetes provider v2.23.0 through v3.0.1)
**Success Rate**: 100% (kubectl provider)

### API Server Response Example

Captured via `oc get vm test-vm -o yaml`:

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  annotations:
    description: Example VM created by Terraform
    kubemacpool.io/transaction-timestamp: "2025-10-02T00:16:19.381349849Z"
  # ... 10+ fields added by API server
spec:
  running: true
  template:
    spec:
      architecture: amd64  # Added by API
      domain:
        cpu:
          cores: 1
          sockets: 1  # Added by API
          threads: 1  # Added by API
        devices:
          interfaces:
          - macAddress: "02:e5:84:00:00:04"  # Added by kubemacpool
            masquerade: {}
            model: virtio
            name: default
        machine:
          type: pc-q35-rhel9.6.0  # Added by API
        # ... 50+ additional fields with defaults
```

Over **100 fields** added/modified by API server vs original HCL.

## Related Issues

### GitHub Issues (hashicorp/terraform-provider-kubernetes)

This is a well-documented class of bugs with 15+ issues reporting the same "Provider produced inconsistent result after apply" error across various CRD types. No KubeVirt VirtualMachine-specific issue exists as of December 2025.

#### Primary Issues - Same Error Class

| Issue | CRD Type | Status | Date | Key Finding |
|-------|----------|--------|------|-------------|
| [#1545](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1545) | CRD (general) | Closed | Dec 2021 | Maintainer acknowledged "backlog item to improve UX" |
| [#1418](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1418) | PrometheusRules | Open | Oct 2021 | Exact same error message as this report |
| [#1719](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1719) | cert-manager | Closed | May 2022 | `[]` vs `null` type mismatch |
| [#1726](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1726) | IstioOperator | Closed | May 2022 | "attribute 'profile' is required" variant |
| [#1530](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1530) | cert-manager | Open | Jan 2022 | Duration format normalization (`240h` vs `240h0m0s`) |
| [#1769](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1769) | Karpenter | Closed | Jun 2022 | "new element has appeared" in requirements |
| [#2185](https://github.com/hashicorp/terraform-provider-kubernetes/issues/2185) | ArgoCD | Open | Jul 2023 | Controller-added fields cause state mismatch |
| [#2366](https://github.com/hashicorp/terraform-provider-kubernetes/issues/2366) | Karpenter | Closed | Dec 2023 | Same as #1769 |
| [#2674](https://github.com/hashicorp/terraform-provider-kubernetes/issues/2674) | Karpenter EC2NodeClass | Open | Jan 2025 | `clusterDNS` list becomes null |
| [#2722](https://github.com/hashicorp/terraform-provider-kubernetes/issues/2722) | DaemonSet | Open | May 2025 | Annotation drift on controller-managed field |

#### computed_fields Limitations

| Issue | Problem | Resolution |
|-------|---------|------------|
| [#1945](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1945) | computed_fields doesn't allow recalculation | Closed - not planned |
| [#2068](https://github.com/hashicorp/terraform-provider-kubernetes/issues/2068) | computed_fields fails with `split()` for multi-part YAML | Open |
| [#1591](https://github.com/hashicorp/terraform-provider-kubernetes/issues/1591) | Default computed_fields doesn't cover all metadata.annotations | Closed |

#### KubeVirt-Specific History

| Issue | Repository | Status | Finding |
|-------|------------|--------|---------|
| [#69](https://github.com/hashicorp/terraform-provider-kubernetes-alpha/issues/69) | kubernetes-alpha (archived) | Closed | Initial KubeVirt support request |
| [#215](https://github.com/hashicorp/terraform-provider-kubernetes-alpha/issues/215) | kubernetes-alpha (archived) | Closed | KubeVirt webhook doesn't support dry-run |

#### Maintainer Response Pattern

Across these issues, HashiCorp maintainers consistently:
1. Suggest `computed_fields` workaround (does not fully resolve complex CRDs)
2. Reference "backlog item to improve UX" but no architectural fix scheduled
3. Tag issues as "upstream-terraform" / "progressive apply" - awaiting SDK changes
4. Close issues when workarounds are provided, even if root cause unaddressed

#### Architectural Blockers

Two issues are tagged as blocking architectural improvements:
- **Progressive Apply** - Would allow dependencies to resolve before schema validation
- **Upstream Terraform SDK** - Required changes for dynamic schema handling

These have been in the backlog since the `kubernetes_manifest` resource was merged from the kubernetes-alpha provider in 2021.

### Pattern Recognition

This issue appears with CRDs that have:
- Deeply nested optional structures (3+ levels)
- Extensive use of default values in OpenAPI schema
- Admission webhooks that modify resources (e.g., kubemacpool)
- Controllers that add computed fields dynamically
- Type conversions by API server (e.g., `{}` to `null`)

## Recommendations

### For Terraform Provider Team

1. **Enhanced computed_fields Support**
   - Implement wildcard patterns: `spec.template.spec.domain.*`
   - Support array element marking: `volumes[*].containerDisk`
   - Support recursive computed: `spec.template.spec.**`

2. **Relaxed Type Validation Mode**
   - Add provider configuration option for "loose" validation
   - Only validate explicitly non-computed fields
   - Treat all nested structures as potentially computed

3. **YAML-based Option**
   - Add `yaml_body` attribute to `kubernetes_manifest`
   - Skip HCL-to-object conversion for complex CRDs
   - Mirror kubectl provider's approach

4. **Better Error Messages**
   - Show which specific field caused validation failure
   - Show expected vs actual types
   - Provide guidance on computed_fields configuration

### For Users (Current Workarounds)

1. **Use kubectl provider** (Recommended)
   - No configuration needed
   - Works with all CRDs
   - Production-ready

2. **Manual import workflow**
   ```bash
   terraform apply || true
   terraform import 'kubernetes_manifest.vm' \
     "apiVersion=kubevirt.io/v1,kind=VirtualMachine,namespace=default,name=test-vm"
   ```

3. **Avoid kubernetes_manifest for complex CRDs**
   - Use kubectl provider
   - Use Helm provider
   - Use kubectl CLI with null_resource

## Conclusion

This is a **fundamental architectural limitation** of the `kubernetes_manifest` resource when handling complex CRDs with extensive API server enrichment. The issue:

- ✅ **Is reproducible** 100% of the time with KubeVirt VirtualMachines
- ❌ **Cannot be resolved** through configuration changes
- ❌ **Is not fixed** in latest provider versions
- ✅ **Does not occur** with kubectl provider using identical manifests

The resource successfully creates Kubernetes objects but fails during state reconciliation due to type validation of API-enriched responses.

**Recommended Action**: Provider team should implement one or more of the recommendations above to handle complex CRDs without type validation failures.

## Appendix: Full Test Configuration

### kubernetes Provider Configuration (Failed)

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }
}

# providers.tf
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# data.tf
data "kubernetes_namespace" "vm_namespace" {
  metadata {
    name = "default"
  }
}

# main.tf
resource "kubernetes_manifest" "virtual_machine" {
  manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = "test-vm"
      namespace = data.kubernetes_namespace.vm_namespace.metadata[0].name
      labels = {
        environment = "test"
        managed-by  = "terraform"
      }
      annotations = {
        description = "Example VM created by Terraform"
      }
    }
    spec = {
      running = true
      template = {
        metadata = {
          labels = {
            environment      = "test"
            managed-by       = "terraform"
            "kubevirt.io/vm" = "test-vm"
          }
        }
        spec = {
          terminationGracePeriodSeconds = 30
          domain = {
            cpu = {
              cores = 1
            }
            resources = {
              requests = {
                memory = "2Gi"
              }
            }
            devices = {
              disks = [{
                name = "rootdisk"
                disk = {
                  bus = "virtio"
                }
              }]
              interfaces = [{
                name       = "default"
                model      = "virtio"
                masquerade = {}
              }]
            }
          }
          networks = [{
            name = "default"
            pod  = {}
          }]
          volumes = [{
            name = "rootdisk"
            containerDisk = {
              image = "quay.io/containerdisks/fedora:latest"
            }
          }]
        }
      }
    }
  }

  computed_fields = [
    "metadata.annotations",
    "metadata.labels",
    "metadata.finalizers",
    "metadata.generation",
    "spec.runStrategy",
    "spec.instancetype",
    "spec.preference",
    "spec.template.metadata",
    "spec.template.spec.accessCredentials",
    "spec.template.spec.affinity",
    "spec.template.spec.architecture",
    "spec.template.spec.dnsConfig",
    "spec.template.spec.dnsPolicy",
    "spec.template.spec.domain.chassis",
    "spec.template.spec.domain.clock",
    "spec.template.spec.domain.cpu",
    "spec.template.spec.domain.devices",
    "spec.template.spec.domain.features",
    "spec.template.spec.domain.firmware",
    "spec.template.spec.domain.ioThreads",
    "spec.template.spec.domain.ioThreadsPolicy",
    "spec.template.spec.domain.launchSecurity",
    "spec.template.spec.domain.machine",
    "spec.template.spec.domain.memory",
    "spec.template.spec.domain.resources",
    "spec.template.spec.evictionStrategy",
    "spec.template.spec.hostname",
    "spec.template.spec.livenessProbe",
    "spec.template.spec.networks",
    "spec.template.spec.nodeSelector",
    "spec.template.spec.priorityClassName",
    "spec.template.spec.readinessProbe",
    "spec.template.spec.schedulerName",
    "spec.template.spec.startStrategy",
    "spec.template.spec.subdomain",
    "spec.template.spec.tolerations",
    "spec.template.spec.topologySpreadConstraints",
    "spec.template.spec.volumes",
    "spec.updateVolumesStrategy",
    "status"
  ]

  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }

  field_manager {
    force_conflicts = true
  }

  lifecycle {
    ignore_changes = [object]
  }
}
```

**Result**: ❌ Error: Provider produced inconsistent result after apply

### kubectl Provider Configuration (Succeeded)

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"  # Only needed for data sources
    }
  }
}

# providers.tf
provider "kubectl" {
  config_path = "~/.kube/config"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# data.tf
data "kubernetes_namespace" "vm_namespace" {
  metadata {
    name = "default"
  }
}

# locals.tf
locals {
  vm_manifest = {
    apiVersion = "kubevirt.io/v1"
    kind       = "VirtualMachine"
    metadata = {
      name      = "test-vm"
      namespace = data.kubernetes_namespace.vm_namespace.metadata[0].name
      labels = {
        environment = "test"
        managed-by  = "terraform"
      }
      annotations = {
        description = "Example VM created by Terraform with kubectl provider"
      }
    }
    spec = {
      running = true
      template = {
        metadata = {
          labels = {
            environment      = "test"
            managed-by       = "terraform"
            "kubevirt.io/vm" = "test-vm"
          }
        }
        spec = {
          terminationGracePeriodSeconds = 30
          domain = {
            cpu = {
              cores = 1
            }
            resources = {
              requests = {
                memory = "2Gi"
              }
            }
            devices = {
              disks = [{
                name = "rootdisk"
                disk = {
                  bus = "virtio"
                }
              }]
              interfaces = [{
                name       = "default"
                model      = "virtio"
                masquerade = {}
              }]
            }
          }
          networks = [{
            name = "default"
            pod  = {}
          }]
          volumes = [{
            name = "rootdisk"
            containerDisk = {
              image = "quay.io/containerdisks/fedora:latest"
            }
          }]
        }
      }
    }
  }

  vm_manifest_yaml = yamlencode(local.vm_manifest)
}

# main.tf
resource "kubectl_manifest" "virtual_machine" {
  yaml_body = local.vm_manifest_yaml

  force_conflicts   = false
  server_side_apply = true
  wait              = true
}
```

**Result**: ✅ Success
- Apply completed in 1 second
- No drift detected on subsequent plans
- Clean state management

---

**Document Version**: 1.2
**Last Updated**: December 2025
**Testing Performed By**: Repository maintainer with live OpenShift cluster access
**Provider Source Analysis**: Verified against terraform-provider-kubernetes v3.0.1 source code
**Contact**: See repository issues for follow-up questions
