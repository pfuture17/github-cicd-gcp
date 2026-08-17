variable "project_id" {
  description = "GCP project that will own the buckets."
  type        = string
}

variable "location" {
  description = "Default bucket location (region such as us-central1, or multi-region such as US)."
  type        = string
}

variable "buckets" {
  description = "Map of buckets to create. The map key is the globally unique bucket name."
  type = map(object({
    location           = optional(string)
    storage_class      = optional(string, "STANDARD")
    versioning_enabled = optional(bool, true)
    force_destroy      = optional(bool, false)
    labels             = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for name in keys(var.buckets) :
      can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", name))
    ])
    error_message = "Each bucket name must be 3-63 characters, lowercase, and start and end with a letter or number."
  }

  validation {
    condition = alltrue([
      for b in values(var.buckets) :
      contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], b.storage_class)
    ])
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}
