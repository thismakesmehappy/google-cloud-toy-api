# Production Environment Configuration
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Shared resources (APIs and IAM)
module "shared" {
  source = "../../shared"

  project_id = var.project_id
}

# Cloud Run Service
module "cloud_run" {
  source = "../../modules/cloud-run"

  project_id      = var.project_id
  region          = var.region
  environment     = var.environment
  container_image = var.container_image

  # Production-specific settings (most restrictive)
  enable_public_access        = false # Only authenticated access
  enable_authenticated_access = true
  
  # Higher resource limits for production
  cpu_limit     = "2000m"
  memory_limit  = "2Gi"
  min_instances = 1    # Always have at least 1 instance for better response times
  max_instances = 100  # Can scale higher for production traffic

  environment_variables = {
    API_KEY = var.api_key
  }

  depends_on = [
    module.shared
  ]
}

# Firestore Database
module "firestore" {
  source = "../../modules/firestore"

  project_id                = var.project_id
  location_id               = var.region
  delete_protection_enabled = true # Always enable protection for production

  depends_on = [
    module.shared
  ]
}