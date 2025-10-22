variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key for server access"
  type        = string
  default     = "homelab"
}

variable "network_name" {
  description = "Name of the private network"
  type        = string
  default     = "homelab"
}

variable "network_ip_range" {
  description = "IP range for the private network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "network_subnet_range" {
  description = "IP range for the network subnet"
  type        = string
  default     = "10.0.0.0/24"
}
