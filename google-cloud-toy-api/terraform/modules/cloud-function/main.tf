# Cloud Function Module
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

# Storage bucket for Cloud Function source code
resource "google_storage_bucket" "source_bucket" {
  name          = "${var.project_id}-cloudfunctions-source-${var.environment}"
  location      = "US"
  force_destroy = true
  project       = var.project_id

  uniform_bucket_level_access = true
  
  lifecycle {
    prevent_destroy = true
  }
}

# Archive the source code and upload to the bucket
resource "google_storage_bucket_object" "source_archive" {
  name   = "source-${var.source_hash}.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = var.source_archive_path
}

# Cloud Function
resource "google_cloudfunctions2_function" "function" {
  name        = "toy-api-function-${var.environment}"
  location    = var.region
  description = "Toy API Cloud Function for ${var.environment} environment"
  project     = var.project_id

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.source_bucket.name
        object = google_storage_bucket_object.source_archive.name
      }
    }
  }

  service_config {
    available_memory = var.memory_mb
    timeout_seconds  = var.timeout_seconds
    environment_variables = merge(
      {
        NODE_ENV                       = var.environment
        GOOGLE_APPLICATION_CREDENTIALS = ""
      },
      var.environment_variables
    )
    ingress_settings = var.ingress_settings
  }

  depends_on = [
    google_storage_bucket.source_bucket
  ]
}

# IAM binding for Cloud Function invoker (API Gateway service account)
resource "google_cloudfunctions2_function_iam_member" "api_gateway_invoker" {
  count          = var.enable_api_gateway_access ? 1 : 0
  project        = google_cloudfunctions2_function.function.project
  location       = google_cloudfunctions2_function.function.location
  cloud_function = google_cloudfunctions2_function.function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:service-${var.project_number}@gcp-sa-apigateway.iam.gserviceaccount.com"
}

# IAM binding for public access (for testing)
resource "google_cloudfunctions2_function_iam_member" "public_invoker" {
  count          = var.enable_public_access ? 1 : 0
  project        = google_cloudfunctions2_function.function.project
  location       = google_cloudfunctions2_function.function.location
  cloud_function = google_cloudfunctions2_function.function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}

# IAM binding for Cloud Run public access (Cloud Functions v2 runs on Cloud Run)
resource "google_cloud_run_service_iam_member" "public_run_invoker" {
  count    = var.enable_public_access ? 1 : 0
  project  = var.project_id
  location = var.region
  service  = google_cloudfunctions2_function.function.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}