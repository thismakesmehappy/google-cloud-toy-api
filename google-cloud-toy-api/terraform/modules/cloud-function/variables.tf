variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
}

variable "project_number" {
  description = "The number of the Google Cloud project"
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

variable "source_archive_path" {
  description = "Path to the source code archive"
  type        = string
}

variable "source_hash" {
  description = "Hash of the source code for versioning"
  type        = string
}

variable "runtime" {
  description = "Runtime for the Cloud Function"
  type        = string
  default     = "nodejs20"
}

variable "entry_point" {
  description = "Entry point function name"
  type        = string
  default     = "app"
}

variable "memory_mb" {
  description = "Memory allocation for the function"
  type        = string
  default     = "256Mi"
}

variable "timeout_seconds" {
  description = "Timeout for the function in seconds"
  type        = number
  default     = 300
}

variable "environment_variables" {
  description = "Environment variables for the function"
  type        = map(string)
  default     = {}
}

variable "ingress_settings" {
  description = "Ingress settings for the function"
  type        = string
  default     = "ALLOW_INTERNAL_ONLY"
}

variable "enable_api_gateway_access" {
  description = "Whether to enable API Gateway access"
  type        = bool
  default     = true
}

variable "enable_public_access" {
  description = "Whether to enable public access (for testing)"
  type        = bool
  default     = false
}