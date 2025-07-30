variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
  default     = "toy-api-staging"
}

variable "region" {
  description = "The Google Cloud region to deploy resources to"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "staging"
}

variable "container_image" {
  description = "The container image to deploy to Cloud Run"
  type        = string
  # This will be set by the deployment script
  default     = "gcr.io/toy-api-staging/toy-api:latest"
}

variable "api_key" {
  description = "API key for authentication"
  type        = string
  default     = "staging-api-key-456"
  sensitive   = true
}