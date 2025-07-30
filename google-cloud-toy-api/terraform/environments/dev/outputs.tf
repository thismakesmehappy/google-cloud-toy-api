output "service_url" {
  description = "The URL of the Cloud Run service"
  value       = module.cloud_run.service_url
}

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = module.cloud_run.service_name
}

output "service_account_email" {
  description = "The email of the service account used by the Cloud Run service"
  value       = module.cloud_run.service_account_email
}

output "firestore_database" {
  description = "The Firestore database name"
  value       = module.firestore.database_name
}