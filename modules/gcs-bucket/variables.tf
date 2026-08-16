variable "project_id" {
  description = "GCP project that will own the bucket."
  type        = string
}

variable "name" {
  description = "Bucket name. Must be globally unique across all of Google Cloud."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.name))
    error_message = "Bucket names must be 3-63 characters, lowercase, and start and end with a letter or number."
  }
}

variable "location" {
  description = "Bucket location. A region such as us-central1, or a multi-region such as US."
  type        = string
}

variable "storage_class" {
  description = "Default storage class for objects in the bucket."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "versioning_enabled" {
  description = "Keep noncurrent versions of overwritten or deleted objects."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow OpenTofu to delete a bucket that still contains objects. Dangerous; leave false unless the bucket is disposable."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to the bucket."
  type        = map(string)
  default     = {}
}
