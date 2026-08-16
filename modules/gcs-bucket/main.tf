resource "google_storage_bucket" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location

  storage_class = var.storage_class
  force_destroy = var.force_destroy

  # IAM is the only access-control mechanism; legacy ACLs are disabled.
  uniform_bucket_level_access = true

  # Blocks any future IAM binding that would expose the bucket publicly.
  public_access_prevention = "enforced"

  versioning {
    enabled = var.versioning_enabled
  }

  labels = var.labels
}
