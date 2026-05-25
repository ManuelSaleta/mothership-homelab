variable "proxmox_endpoint" {
  type        = string
  description = "The full HTTPS URL API endpoint for the Proxmox VE host"
  default     = "https://192.168.50.200:8006/"
}

variable "proxmox_api_token" {
  type        = string
  description = "The complete concatenated Proxmox API token ID and Secret string"
  sensitive   = true # Mask this value out of standard CLI console log outputs
}