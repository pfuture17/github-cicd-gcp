output "name" {
  description = "Name of the bucket."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "self_link" {
  description = "URI of the bucket in the Cloud Storage API."
  value       = google_storage_bucket.this.self_link
}
