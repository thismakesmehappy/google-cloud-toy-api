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
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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

# Archive the source code
data "archive_file" "source_zip" {
  type        = "zip"
  source_dir  = "../../../src"
  output_path = "function-source.zip"
  excludes    = ["tsconfig.json", "_HIDDEN/"]
}

# Cloud Function
module "cloud_function" {
  source = "../../modules/cloud-function"

  project_id          = var.project_id
  project_number      = module.shared.project_number
  region              = var.region
  environment         = var.environment
  source_archive_path = data.archive_file.source_zip.output_path
  source_hash         = data.archive_file.source_zip.output_base64sha256

  # Production-specific settings
  memory_mb            = "512Mi"               # More memory for production
  ingress_settings     = "ALLOW_INTERNAL_ONLY" # Most restrictive
  enable_public_access = false                 # No public access

  depends_on = [
    module.shared
  ]
}

# Firestore Database
module "firestore" {
  source = "../../modules/firestore"

  project_id                = var.project_id
  location_id               = var.region
  delete_protection_enabled = true # Enable protection for production

  depends_on = [
    module.shared
  ]
}

# API Gateway
module "api_gateway" {
  source = "../../modules/api-gateway"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  openapi_spec = templatefile("${path.module}/openapi.yaml", {
    backend_url = module.cloud_function.function_url
    project_id  = var.project_id
  })

  depends_on = [
    module.cloud_function,
    module.shared
  ]
}