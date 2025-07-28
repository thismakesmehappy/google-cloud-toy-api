output "project_number" {
  description = "The number of the Google Cloud project"
  value       = data.google_project.project.number
}

output "project_id" {
  description = "The ID of the Google Cloud project"
  value       = data.google_project.project.project_id
}