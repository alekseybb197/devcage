packer {
  required_version = ">= 1.10.0"
  required_plugins {
    docker = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/docker"
    }
  }
}

source "docker" "qwen" {
  image  = var.base_image
  commit = true

  changes = [
    "ENTRYPOINT [\"/usr/local/bin/entrypoint.sh\"]"
  ]
}

build {
  name    = "qwen-code-image"
  sources = ["source.docker.qwen"]

  # Conditional copy of certificates and related setup
  dynamic "provisioner" {
    for_each = var.copy_certs ? [1] : []
    labels   = ["file"]
    content {
      source      = "ca-certificates"
      destination = "/usr/local/share/ca-certificates"
    }
  }

  dynamic "provisioner" {
    for_each = var.copy_certs ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "mkdir -p /etc/ssl/certs/",
        "cat /usr/local/share/ca-certificates/*.crt >> /etc/ssl/certs/ca-certificates.crt",
        "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates && apt-get clean && rm -rf /var/lib/apt/lists/*",
        "update-ca-certificates"
      ]
    }
  }

  # Conditional copy of custom Debian sources list
  dynamic "provisioner" {
    for_each = var.copy_sources ? [1] : []
    labels   = ["file"]
    content {
      source      = "debian.sources"
      destination = "/etc/apt/sources.list.d/debian.sources"
    }
  }

  dynamic "provisioner" {
    for_each = var.copy_sources ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "apt-get update",
        "apt-get clean",
        "rm -rf /var/lib/apt/lists/*"
      ]
    }
  }

  # System dependencies
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y git curl wget gnupg2 python3 python3-pip python3-venv make g++ openssh-client bsdutils asciinema procps",
      "rm -rf /var/lib/apt/lists/*"
    ]
  }

  # Conditional install of PlantUML and related packages
  dynamic "provisioner" {
    for_each = var.install_plantuml ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "apt-get update",
        "apt-get install -y plantuml default-jre graphviz",
        "rm -rf /var/lib/apt/lists/*"
      ]
    }
  }

  # Conditional download of kubectl binary
  dynamic "provisioner" {
    for_each = var.copy_kubectl ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')",
        "KUBECTL_VERSION=${var.kubectl_version}",
        "curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/release/v$${KUBECTL_VERSION}/bin/linux/$${ARCH}/kubectl",
        "chmod +x /usr/local/bin/kubectl"
      ]
    }
  }

  # Conditional download of helm binary
  dynamic "provisioner" {
    for_each = var.copy_helm ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')",
        "HELM_VERSION=${var.helm_version}",
        "curl -L -o helm.tar.gz https://get.helm.sh/helm-v$${HELM_VERSION}-linux-$${ARCH}.tar.gz",
        "tar -xzvf helm.tar.gz",
        "mv linux-$${ARCH}/helm /usr/local/bin/helm",
        "chmod +x /usr/local/bin/helm",
        "rm -rf helm.tar.gz linux-$${ARCH}"
      ]
    }
  }

  # Conditional download of yq binary
  dynamic "provisioner" {
    for_each = var.copy_yq ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')",
        "YQ_VERSION=${var.yq_version}",
        "curl -L -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v$${YQ_VERSION}/yq_linux_$${ARCH}",
        "chmod +x /usr/local/bin/yq"
      ]
    }
  }

  # Conditional download of jq binary
  dynamic "provisioner" {
    for_each = var.copy_jq ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')",
        "JQ_VERSION=${var.jq_version}",
        "curl -L -o /usr/local/bin/jq https://github.com/jqlang/jq/releases/download/jq-$${JQ_VERSION}/jq-linux64",
        "chmod +x /usr/local/bin/jq"
      ]
    }
  }

  # Install nodejs via nodesource and qwen-code CLI
  provisioner "shell" {
    inline = [
      "mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg",
      "echo \"deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${var.nodejs_version}.x nodistro main\" | tee /etc/apt/sources.list.d/nodesource.list",
      "apt-get update",
      "apt-get install -y nodejs",
      "rm -rf /var/lib/apt/lists/*",
      "npm install -g @qwen-code/qwen-code@latest"
    ]
  }

  # Create user 'agent'
  provisioner "shell" {
    inline = ["useradd -m -s /bin/bash agent"]
  }

  # Copy entrypoint script
  provisioner "file" {
    source      = "entrypoint.sh"
    destination = "/usr/local/bin/entrypoint.sh"
  }

  provisioner "shell" {
    inline = ["chmod +x /usr/local/bin/entrypoint.sh"]
  }

  # Setup home directory and workspace permissions
  provisioner "shell" {
    inline = [
      "chown -R agent:agent /home/agent",
      "mkdir -p /home/agent/workspace",
      "chown -R agent:agent /home/agent/workspace"
    ]
  }

  # Conditional install of Go language
  dynamic "provisioner" {
    for_each = var.install_go ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "apt-get update",
        "apt-get install -y wget",
        "wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz -O /tmp/go1.22.0.linux-amd64.tar.gz",
        "tar -C /usr/local -xzf /tmp/go1.22.0.linux-amd64.tar.gz",
        "rm /tmp/go1.22.0.linux-amd64.tar.gz",
        "echo \"export PATH=\\$PATH:/usr/local/go/bin\" >> /home/agent/.profile",
        "echo \"export GOPATH=\\$HOME/go\" >> /home/agent/.profile",
        "echo \"export PATH=\\$PATH:\\$GOPATH/bin\" >> /home/agent/.profile",
        "rm -rf /var/lib/apt/lists/*"
      ]
    }
  }

  # Conditional install of ansible
  dynamic "provisioner" {
    for_each = var.install_ansible ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        # Switch to user 'agent' for subsequent layers (no direct USER support, use su)
        "su - agent -c 'python3 -m venv /home/agent/venv'",
        "su - agent -c '/home/agent/venv/bin/pip install --upgrade pip'",
        "su - agent -c '/home/agent/venv/bin/pip install ansible --upgrade'",
        "su - agent -c '/home/agent/venv/bin/pip install ansible-lint --upgrade'"
      ]
    }
  }

  # Set working directory (Dockerfile uses WORKDIR)
  provisioner "shell" {
    inline = ["export WORKDIR=/home/agent/workspace"]
  }

  # Post‑processor to tag the built image
  post-processor "docker-tag" {
    repository = "qwen-code"
    tag        = [var.build_version]
  }
}
