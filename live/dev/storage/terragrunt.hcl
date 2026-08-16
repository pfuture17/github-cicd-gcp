# Unit: dev / storage
#
# One directory containing a terragrunt.hcl == one OpenTofu state file.
# State for this unit lives at:
#   gs://gcp-infra-499507-tfstate/dev/storage/default.tfstate

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/gcs-bucket"
}

inputs = {
  name = "gcp-infra-499507-dev-app-data"

  labels = {
    environment = "dev"
    component   = "storage"
    managed_by  = "terragrunt"
  }
}
