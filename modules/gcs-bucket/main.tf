resource "google_storage_bucket" "this" {
  for_each = var.buckets

  project  = var.project_id
  name     = each.key
  location = coalesce(each.value.location, var.location)

  storage_class = each.value.storage_class
  force_destroy = each.value.force_destroy

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = each.value.versioning_enabled
  }

  labels = each.value.labels
}
