output "function_url" {
  description = "URL of the Cloud Function"
  value       = module.cloud_function.function_url
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${module.api_gateway.gateway_url}"
}

output "function_name" {
  description = "Name of the Cloud Function"
  value       = module.cloud_function.function_name
}