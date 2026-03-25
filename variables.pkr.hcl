variable "base_image" {
  description = "Base Docker image for the build"
  type        = string
  default     = "debian:13.3-slim"
}

variable "kubectl_version" {
  type    = string
  default = "1.35.2"
}

variable "nodejs_version" {
  type    = string
  default = "20"
}

variable "copy_certs" {
  description = "Whether to copy custom CA certificates"
  type        = bool
  default     = true
}

variable "copy_sources" {
  description = "Whether to copy custom Debian sources list"
  type        = bool
  default     = true
}

variable "copy_kubectl" {
  description = "Whether to copy a pre‑downloaded kubectl binary"
  type        = bool
  default     = true
}

variable "helm_version" {
  description = "Helm version to download"
  type        = string
  default     = "3.14.0"
}

variable "copy_helm" {
  description = "Whether to copy a pre‑downloaded helm binary"
  type        = bool
  default     = true
}

variable "yq_version" {
  description = "yq version to download"
  type        = string
  default     = "4.35.1"
}

variable "copy_yq" {
  description = "Whether to copy a pre‑downloaded yq binary"
  type        = bool
  default     = true
}

variable "jq_version" {
  description = "jq version to download"
  type        = string
  default     = "1.6"
}

variable "copy_jq" {
  description = "Whether to copy a pre‑downloaded jq binary"
  type        = bool
  default     = true
}

variable "install_ansible" {
  description = "Whether to install ansible into venv"
  type        = bool
  default     = true
}

variable "install_plantuml" {
  description = "Whether to install PlantUML and its dependencies"
  type        = bool
  default     = true
}

variable "install_go" {
  description = "Whether to install Go programming language"
  type        = bool
  default     = true
}

variable "agent_uid" {
  description = "UID for the agent user inside the container"
  type        = number
  default     = 59998
}

variable "agent_gid" {
  description = "GID for the agent group inside the container"
  type        = number
  default     = 59998
}

variable "build_version" {
  description = "Build version tag for Docker image"
  type        = string
  default     = "0.0.16"
}

variable "pypy_mirror" {
  description = "PyPI mirror for PyPy packages, i.e. https://pypi.tuna.tsinghua.edu.cn/simple"
  type        = string
  default     = "https://pypi.tuna.tsinghua.edu.cn/simple"
}
