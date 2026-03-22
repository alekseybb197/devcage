#!/usr/bin/env bash
# Build the Qwen Code Docker image using Packer.
# Usage: ./build.sh [options]
# Options:
#   --no-certs      Disable copying custom CA certificates (copy_certs=false)
#   --no-sources    Disable copying custom Debian sources (copy_sources=false)
#   --no-kubectl    Skip downloading kubectl inside image (copy_kubectl=false)
#   --no-helm       Skip downloading helm (copy_helm=false)
#   --no-yq         Skip downloading yq (copy_yq=false)
#   --no-jq         Skip downloading jq (copy_jq=false)
#   --no-ansible    Skip installing Ansible (install_ansible=false)
#   --no-plantuml   Skip installing PlantUML and dependencies (install_plantuml=false)
#   --no-go         Skip installing Go (install_go=false)

set -euo pipefail

# Default options
COPY_CERTS=true
COPY_SOURCES=true
COPY_KUBECTL=true
COPY_HELM=true
COPY_YQ=true
COPY_JQ=true
INSTALL_ANSIBLE=true
INSTALL_PLANTUML=true
INSTALL_GO=true

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-certs)   COPY_CERTS=false; shift;;
    --no-sources) COPY_SOURCES=false; shift;;
    --no-kubectl) COPY_KUBECTL=false; shift;;
    --no-helm)    COPY_HELM=false; shift;;
    --no-yq)      COPY_YQ=false; shift;;
    --no-jq)      COPY_JQ=false; shift;;
    --no-ansible) INSTALL_ANSIBLE=false; shift;;
    --no-plantuml) INSTALL_PLANTUML=false; shift;;
    --no-go) INSTALL_GO=false; shift;;
    *)            shift;;
  esac
done

# Auto‑detect presence of files for certificates and sources; if missing, disable copy
if [[ ! -f "debian.sources" ]]; then
  COPY_SOURCES=false
fi
if [[ ! -d "ca-certificates" ]] && [[ "$COPY_CERTS" == true ]]; then
  COPY_CERTS=false
fi

# Run packer with the computed variables
packer build \
  -var "copy_certs=${COPY_CERTS}" \
  -var "copy_sources=${COPY_SOURCES}" \
  -var "copy_kubectl=${COPY_KUBECTL}" \
  -var "copy_helm=${COPY_HELM}" \
  -var "copy_yq=${COPY_YQ}" \
  -var "copy_jq=${COPY_JQ}" \
  -var "install_ansible=${INSTALL_ANSIBLE}" \
  -var "install_plantuml=${INSTALL_PLANTUML}" \
  -var "install_go=${INSTALL_GO}" \
  .

if [ $? -eq 0 ]; then
  # After successful packer build, retag the latest qwen-code image with a '-build' suffix
  IMAGE_TAG=$(docker images --filter=reference='qwen-code:*' --format '{{.Tag}} {{.CreatedAt}}' | sort -r -k2 | head -n1 | awk '{print $1}')
  if [ -n "$IMAGE_TAG" ]; then
    NEW_TAG="${IMAGE_TAG}-build"
    echo "Tagging image qwen-code:${IMAGE_TAG} as qwen-code:${NEW_TAG}"
    docker tag "qwen-code:${IMAGE_TAG}" "qwen-code:${NEW_TAG}"

    # Build a new image with merged layers from the retagged image
    cat <<EOF | docker build -t "qwen-code:${IMAGE_TAG}" -f - .
FROM qwen-code:${NEW_TAG} AS builder
FROM scratch
COPY --from=builder / /
ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
USER agent
WORKDIR /home/agent/workspace
EOF
    # Remove the temporary builder image tagged with -build
    docker rmi "qwen-code:${NEW_TAG}" || true
  else
    echo "No qwen-code image found to retag."
  fi
fi
