terraform {
  required_version = ">= 1.5.0"

  # Generic empty GCS backend.
  # The centralized CI/CD pipeline dynamically injects bucket and prefix flags:
  # -backend-config="bucket=${ENV}-tfstate-bucket" -backend-config="prefix=${ENV}/compute-infrastructure"
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id != "" ? var.project_id : try(local.raw_config.project_id, null)
  region  = var.region != "" ? var.region : try(local.raw_config.region, "us-central1")
}
