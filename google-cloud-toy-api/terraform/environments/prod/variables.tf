variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
  default     = "toy-api-prod"
}

variable "region" {
  description = "The Google Cloud region to deploy resources to"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "prod"
}

variable "container_image" {
  description = "The container image to deploy to Cloud Run"
  type        = string
  # This will be set by the deployment script
  default     = "gcr.io/toy-api-prod/toy-api:latest"
}

variable "api_key" {
  description = "API key for authentication"
  type        = string
  default     = "prod-api-key-789"
  sensitive   = true
}