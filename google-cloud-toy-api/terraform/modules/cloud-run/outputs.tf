output "service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.uri
}

output "service_name" {  
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.name
}

output "service_account_email" {
  description = "The email of the service account used by the Cloud Run service"
  value       = google_service_account.cloudrun_sa.email
}

output "location" {
  description = "The location where the service is deployed"
  value       = google_cloud_run_v2_service.service.location
}