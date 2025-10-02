#!/bin/bash
set -e

# Configuration from environment variables
PACKER_DIR="${PACKER_DIR:-packer}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
RHEL10_IMAGE_URL="${RHEL10_IMAGE_URL:?RHEL10_IMAGE_URL must be set}"
RHEL10_IMAGE_CHECKSUM="${RHEL10_IMAGE_CHECKSUM:?RHEL10_IMAGE_CHECKSUM must be set}"
VAULT_VERSION="${VAULT_VERSION:-1.15.0}"
RHEL_SUB_USERNAME="${RHEL_SUB_USERNAME:-}"
RHEL_SUB_PASSWORD="${RHEL_SUB_PASSWORD:-}"
IMAGE_NAME="${IMAGE_NAME:?IMAGE_NAME must be set}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REGISTRY_URL="${REGISTRY_URL:-quay.io}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"
VM_NAME="${VM_NAME:-rhel10-vault-agent}"

FULL_IMAGE_REF="${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "=================================================="
echo "Building RHEL 10 + Vault Agent Image"
echo "=================================================="
echo "RHEL 10 Image URL: ${RHEL10_IMAGE_URL}"
echo "Vault Version: ${VAULT_VERSION}"
echo "Output Image: ${FULL_IMAGE_REF}"
echo "=================================================="

# Change to packer directory
cd "${PACKER_DIR}"

# Initialize Packer plugins
echo "Initializing Packer plugins..."
packer init .

# Run Packer build
echo "Running Packer build (this may take 10-20 minutes)..."
packer build \
  -var "rhel10_image_url=${RHEL10_IMAGE_URL}" \
  -var "rhel10_image_checksum=${RHEL10_IMAGE_CHECKSUM}" \
  -var "vault_version=${VAULT_VERSION}" \
  -var "rhel_subscription_username=${RHEL_SUB_USERNAME}" \
  -var "rhel_subscription_password=${RHEL_SUB_PASSWORD}" \
  -var "output_directory=${OUTPUT_DIR}" \
  -var "vm_name=${VM_NAME}" \
  rhel10.pkr.hcl

# Go back to module root
cd ..

# Find the built QCOW2 file
QCOW2_FILE=$(ls -t "${PACKER_DIR}/${OUTPUT_DIR}"/*.qcow2 | head -1)
if [ ! -f "${QCOW2_FILE}" ]; then
  echo "ERROR: QCOW2 file not found in ${PACKER_DIR}/${OUTPUT_DIR}/"
  exit 1
fi

echo "Built QCOW2 image: ${QCOW2_FILE}"
QCOW2_SIZE=$(du -h "${QCOW2_FILE}" | cut -f1)
echo "Image size: ${QCOW2_SIZE}"

# Generate Dockerfile from template
echo "Generating Dockerfile..."
QCOW2_BASENAME=$(basename "${QCOW2_FILE}")
cp "${PACKER_DIR}/Dockerfile.tpl" Dockerfile.build
sed -i.bak "s|__QCOW2_FILE__|${QCOW2_FILE}|g" Dockerfile.build
rm -f Dockerfile.build.bak

# Build container image
echo "Building containerDisk image..."
docker build -f Dockerfile.build -t "${FULL_IMAGE_REF}" .

# Clean up temporary Dockerfile
rm -f Dockerfile.build

# Authenticate to registry if credentials provided
if [ -n "${REGISTRY_USERNAME}" ] && [ -n "${REGISTRY_PASSWORD}" ]; then
  echo "Logging in to ${REGISTRY_URL}..."
  echo "${REGISTRY_PASSWORD}" | docker login "${REGISTRY_URL}" -u "${REGISTRY_USERNAME}" --password-stdin
fi

# Push to registry
echo "Pushing image to registry..."
docker push "${FULL_IMAGE_REF}"

echo "=================================================="
echo "Build complete!"
echo "Image: ${FULL_IMAGE_REF}"
echo "=================================================="

# Output the full image reference for Terraform to capture
echo "${FULL_IMAGE_REF}" > /tmp/packer_image_ref.txt
