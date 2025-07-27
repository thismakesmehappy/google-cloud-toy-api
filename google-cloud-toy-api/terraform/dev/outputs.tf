output "api_gateway_url" {
  description = "The URL of the deployed API Gateway."
  value       = google_api_gateway_gateway.toy_api_gateway_instance.default_hostname
}

output "cloud_function_url" {
  description = "The URL of the deployed Cloud Function."
  value       = google_cloudfunctions2_function.toy_api_function.url
}
