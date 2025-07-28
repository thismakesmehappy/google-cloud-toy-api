variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "database_name" {
  description = "Name of the Firestore database"
  type        = string
  default     = "(default)"
}

variable "location_id" {
  description = "Location ID for the Firestore database"
  type        = string
  default     = "us-central1"
}

variable "database_type" {
  description = "Type of the Firestore database"
  type        = string
  default     = "FIRESTORE_NATIVE"
}

variable "delete_protection_enabled" {
  description = "Whether to enable delete protection"
  type        = bool
  default     = false
}