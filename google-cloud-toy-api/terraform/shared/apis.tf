# Shared API enablement
variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
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

# Get project data
data "google_project" "project" {
  project_id = var.project_id
}

# Note: IAM bindings for API Gateway are configured manually 
# via setup scripts to avoid permission issues in CI/CD
# These bindings already exist:
# - roles/run.admin for compute service account
# - roles/iam.serviceAccountTokenCreator for API Gateway service account  
# - roles/iam.serviceAccountUser for API Gateway to act as compute service account