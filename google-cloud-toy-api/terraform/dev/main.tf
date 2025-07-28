# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable necessary APIs
resource "google_project_service" "cloudfunctions_api" {
  project            = var.project_id
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "apigateway_api" {
  project            = var.project_id
  service            = "apigateway.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "firestore_api" {
  project            = var.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild_api" {
  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  project            = var.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudrun_api" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_iam_member" "cloud_functions_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "api_gateway_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-apigateway.iam.gserviceaccount.com"
}

resource "google_service_account_iam_member" "api_gateway_can_act_as_function_sa" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-apigateway.iam.gserviceaccount.com"
}

# Cloud Function for the API
resource "google_cloudfunctions2_function" "toy_api_function" {
  name        = "toy-api-function-${var.environment}"
  location    = var.region
  description = "Toy API Cloud Function for ${var.environment} environment"
  project     = var.project_id

  build_config {
    runtime     = "nodejs20" # Or nodejs20 if preferred and available
    entry_point = "app"      # The name of the exported function in index.js
    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = google_storage_bucket_object.source_archive.name
      }
    }
  }

  service_config {
    available_memory = "256Mi" # Adjust based on free tier limits and needs
    timeout_seconds  = 300
    environment_variables = {
      NODE_ENV                       = var.environment
      GOOGLE_APPLICATION_CREDENTIALS = ""
      # Add other environment variables here if needed
    }
    ingress_settings = "ALLOW_ALL" # Temporarily allow all for testing
  }

  depends_on = [
    google_project_service.cloudfunctions_api,
    google_project_service.cloudbuild_api,
    google_storage_bucket.source_bucket
  ]
}

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "source_bucket" {
  name          = "${var.project_id}-cloudfunctions-source" # Must be globally unique
  location      = "US"                                      # Multi-region for source bucket
  force_destroy = true                                      # Allows bucket to be destroyed even if not empty
  project       = var.project_id

  uniform_bucket_level_access = true
}

# Archive the source code and upload to the bucket
resource "google_storage_bucket_object" "source_archive" {
  name   = "source-${timestamp()}.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.source_zip.output_path
}

data "archive_file" "source_zip" {
  type        = "zip"
  source_dir  = "../../" # Path to your Node.js source code
  output_path = "function-source.zip"
  excludes    = ["tsconfig.json", "_HIDDEN/"]
}

# Firestore Database
resource "google_firestore_database" "database" {
  project                 = var.project_id
  name                    = "(default)" # Default database
  location_id             = var.region  # Must be same as Cloud Function for optimal performance
  type                    = "FIRESTORE_NATIVE"
  delete_protection_state = "DELETE_PROTECTION_DISABLED" # For easy destruction in dev

  depends_on = [
    google_project_service.firestore_api
  ]
}

# API Gateway
resource "google_api_gateway_api" "toy_api_gateway" {
  provider = google-beta
  api_id   = "toy-api-v2-${var.environment}"
  project  = var.project_id

  depends_on = [
    google_project_service.apigateway_api
  ]
}

resource "google_api_gateway_api_config" "toy_api_config" {
  provider      = google-beta
  api           = google_api_gateway_api.toy_api_gateway.api_id
  api_config_id = "default" # Or a version like "v1"
  project       = var.project_id

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = filebase64("openapi.yaml") # We will create this file next
    }
  }

  depends_on = [
    google_cloudfunctions2_function.toy_api_function
  ]
}

resource "google_api_gateway_gateway" "toy_api_gateway_instance" {
  provider   = google-beta
  gateway_id = "toy-api-gateway-v2-${var.environment}"
  api_config = google_api_gateway_api_config.toy_api_config.id
  project    = var.project_id

  depends_on = [
    google_api_gateway_api_config.toy_api_config
  ]
}

# Get project number for API Gateway service account
data "google_project" "project" {
  project_id = var.project_id
}

# IAM binding for Cloud Function invoker (API Gateway service account)
resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.toy_api_function.project
  location       = google_cloudfunctions2_function.toy_api_function.location
  cloud_function = google_cloudfunctions2_function.toy_api_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-apigateway.iam.gserviceaccount.com"

  depends_on = [
    google_cloudfunctions2_function.toy_api_function,
    google_project_service.iam_api
  ]
}

# IAM binding for public access (for testing)
resource "google_cloudfunctions2_function_iam_member" "public_invoker" {
  project        = google_cloudfunctions2_function.toy_api_function.project
  location       = google_cloudfunctions2_function.toy_api_function.location
  cloud_function = google_cloudfunctions2_function.toy_api_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"

  depends_on = [
    google_cloudfunctions2_function.toy_api_function,
    google_project_service.iam_api
  ]
}

# IAM binding for Cloud Run public access (Cloud Functions v2 runs on Cloud Run)
resource "google_cloud_run_service_iam_member" "public_run_invoker" {
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.toy_api_function.name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [
    google_cloudfunctions2_function.toy_api_function,
    google_project_service.cloudrun_api
  ]
}
