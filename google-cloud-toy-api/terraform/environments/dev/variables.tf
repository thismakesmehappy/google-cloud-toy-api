variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
  default     = "toy-api-dev"
}

variable "region" {
  description = "The Google Cloud region to deploy resources to"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "dev"
}

variable "container_image" {
  description = "The container image to deploy to Cloud Run"
  type        = string
  # This will be set by the CI/CD pipeline
  default     = "gcr.io/toy-api-dev/toy-api:latest"
}

variable "api_key" {
  description = "API key for authentication"
  type        = string
  default     = "dev-api-key-123"
  sensitive   = true
}