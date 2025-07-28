output "gateway_url" {
  description = "URL of the API Gateway"
  value       = google_api_gateway_gateway.gateway.default_hostname
}

output "api_id" {
  description = "ID of the API"
  value       = google_api_gateway_api.api.api_id
}

output "gateway_id" {
  description = "ID of the Gateway"
  value       = google_api_gateway_gateway.gateway.gateway_id
}