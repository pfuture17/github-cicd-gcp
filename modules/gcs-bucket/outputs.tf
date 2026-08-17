output "names" {
  description = "Names of the created buckets."
  value       = [for b in google_storage_bucket.this : b.name]
}

output "urls" {
  description = "gs:// URLs of the created buckets."
  value       = { for name, b in google_storage_bucket.this : name => b.url }
}
