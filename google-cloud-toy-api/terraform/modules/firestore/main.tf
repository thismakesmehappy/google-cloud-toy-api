# Firestore Module
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Firestore Database
resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = var.database_name
  location_id = var.location_id
  type        = var.database_type
  delete_protection_state = var.delete_protection_enabled ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"
}