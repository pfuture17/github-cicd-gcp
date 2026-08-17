# Unit: dev / storage
#
# All GCS data buckets live in THIS unit, so they share ONE state file:
#   gs://gcp-infra-499507-tfstate/dev/storage/default.tfstate
#
# The bootstrap state bucket (gcp-infra-499507-tfstate) is NOT managed here.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/gcs-bucket"
}

inputs = {
  buckets = {
    "gcp-infra-499507-dev-raw" = {
      labels = {
        environment = "dev"
        component   = "storage"
        purpose     = "raw-ingest"
        managed_by  = "terragrunt"
      }
    }

    "gcp-infra-499507-dev-curated" = {
      labels = {
        environment = "dev"
        component   = "storage"
        purpose     = "curated"
        managed_by  = "terragrunt"
      }
    }

    "gcp-infra-499507-dev-scratch" = {
      force_destroy = true
      labels = {
        environment = "dev"
        component   = "storage"
        purpose     = "scratch"
        managed_by  = "terragrunt"
      }
    }
  }
}
