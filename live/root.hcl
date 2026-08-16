# Root Terragrunt configuration.
#
# Every unit under live/ includes this file. It exists so that backend and
# provider configuration are written once rather than copied into each unit.
#
# Must NOT be named terragrunt.hcl: Terragrunt's root-terragrunt-hcl strict
# control rejects referencing a root terragrunt.hcl via find_in_parent_folders.

locals {
  project_id   = "gcp-infra-499507"
  region       = "us-central1"
  state_bucket = "gcp-infra-499507-tfstate"
}

# Generates backend.tf into each unit's working directory.
# The state prefix is derived from the unit's path under live/, so
# live/dev/storage stores state at dev/storage/default.tfstate. Directory
# layout and state layout cannot drift apart.
remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = local.state_bucket

    # path_relative_to_include() uses the host OS separator, so on Windows it
    # yields "dev\storage" while a Linux CI runner yields "dev/storage" - two
    # different GCS objects for the same unit. Normalise so every platform
    # addresses identical state.
    prefix = replace(path_relative_to_include(), "\\", "/")
  }
}

# Generates provider.tf into each unit's working directory.
# No credentials appear here. The provider resolves them through Application
# Default Credentials: gcloud locally, Workload Identity Federation in CI.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    provider "google" {
      project = "${local.project_id}"
      region  = "${local.region}"
    }
  EOF
}

# Inputs shared by every unit. Units may override any of these.
inputs = {
  project_id = local.project_id
  location   = local.region
}
