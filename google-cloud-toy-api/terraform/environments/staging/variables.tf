variable "project_id" {
  description = "The ID of the Google Cloud project"
  type        = string
  default     = "toy-api-stage"
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