variable "app_version" {
  type        = string
  description = "Application release version tag"
  default     = "1.0.0"
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to the local kubeconfig file"
  default     = "~/.kube/config"
}

variable "nomad_address" {
  type        = string
  description = "API address for the HashiCorp Nomad agent"
  default     = "http://127.0.0.1:4646"
}

variable "nomad_datacenter" {
  type        = string
  description = "Target Nomad Datacenter"
  default     = "dc1"
}
