# Cloud Run Module
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Build and push Docker image to Container Registry
resource "google_cloud_run_v2_service" "service" {
  name     = "toy-api-service-${var.environment}"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = var.container_image
      
      ports {
        container_port = 8080
      }
      
      env {
        name  = "NODE_ENV"
        value = var.environment
      }
      
      env {
        name  = "PORT"
        value = "8080"
      }
      
      # Add any additional environment variables
      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }
      
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }
    }
    
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
    
    # Service account for the Cloud Run service
    service_account = google_service_account.cloudrun_sa.email
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_service.cloudrun_api
  ]
}

# Service account for Cloud Run service
resource "google_service_account" "cloudrun_sa" {
  account_id   = "cloudrun-sa-${var.environment}"
  display_name = "Cloud Run Service Account for ${var.environment}"
  project      = var.project_id
}

# Grant Cloud Run service account access to Firestore
resource "google_project_iam_member" "cloudrun_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Enable Cloud Run API
resource "google_project_service" "cloudrun_api" {
  project = var.project_id
  service = "run.googleapis.com"
  
  disable_on_destroy = false
}

# IAM binding for public access (if enabled)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.enable_public_access ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM binding for authenticated access
resource "google_cloud_run_v2_service_iam_member" "authenticated_access" {
  count    = var.enable_authenticated_access ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
}