variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  default     = ""
}

variable "region" {
  description = "Default Google Cloud Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment target environment (dev, uat, prod)"
  type        = string
  default     = "dev"
}

variable "config_file" {
  description = "Path to YAML configuration file for VMs"
  type        = string
  default     = ""
}
