variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy resources to"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "api_config_id" {
  description = "ID for the API configuration"
  type        = string
  default     = "default"
}

variable "openapi_spec" {
  description = "OpenAPI specification content"
  type        = string
}