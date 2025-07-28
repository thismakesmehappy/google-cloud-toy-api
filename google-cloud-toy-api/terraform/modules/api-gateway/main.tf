# API Gateway Module
terraform {
  required_providers {
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# API Gateway
resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "toy-api-${var.environment}"
  project  = var.project_id
}

resource "google_api_gateway_api_config" "config" {
  provider      = google-beta
  api           = google_api_gateway_api.api.api_id
  api_config_id = var.api_config_id
  project       = var.project_id

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(var.openapi_spec)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "gateway" {
  provider   = google-beta
  gateway_id = "toy-api-gateway-${var.environment}"
  api_config = google_api_gateway_api_config.config.id
  project    = var.project_id
}