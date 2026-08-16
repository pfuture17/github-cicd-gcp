# Bootstrap

Resources in this document are created **manually** and are deliberately **not**
managed by OpenTofu.

## Why

Everything here must exist *before* the CI/CD pipeline can authenticate or store
state. Managing them with OpenTofu would be circular:

- The state bucket cannot be created by the tool that needs it to record state.
- The service account cannot be created by a pipeline that needs it to run.
- The Workload Identity provider cannot be created by a workflow that needs it
  to authenticate.

These are one-time, permanent fixtures. Recreate them only when rebuilding the
project from scratch.

## Environment

| Item            | Value                        |
| --------------- | ---------------------------- |
| Project ID      | `gcp-infra-499507`           |
| Project number  | `1063348389495`              |
| Region          | `us-central1`                |
| State bucket    | `gcp-infra-499507-tfstate`   |

## 1. Enable required APIs

```bash
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  serviceusage.googleapis.com \
  --project=gcp-infra-499507
```

Idempotent. Enabling an already-enabled API is a no-op.

## 2. Create the remote state bucket

```bash
gcloud storage buckets create gs://gcp-infra-499507-tfstate \
  --project=gcp-infra-499507 \
  --location=us-central1 \
  --uniform-bucket-level-access \
  --public-access-prevention
```

Then enable object versioning, which `create` does not support:

```bash
gcloud storage buckets update gs://gcp-infra-499507-tfstate --versioning
```

Re-running `create` returns HTTP 409 and changes nothing. `update` is idempotent.

Verify:

```bash
gcloud storage buckets describe gs://gcp-infra-499507-tfstate \
  --format="yaml(name,location,storageClass,versioning,uniformBucketLevelAccess,publicAccessPrevention)"
```

## 3. Service account

The identity GitHub Actions assumes. It has **no user-managed keys** and must
never be given any — access is granted exclusively through Workload Identity
Federation (section 4).

```bash
gcloud iam service-accounts create github-actions-deployer \
  --project=gcp-infra-499507 \
  --display-name="GitHub Actions OpenTofu deployer" \
  --description="Assumed by GitHub Actions via Workload Identity Federation to manage infrastructure. No keys."
```

Email: `github-actions-deployer@gcp-infra-499507.iam.gserviceaccount.com`

### Roles

```bash
gcloud projects add-iam-policy-binding gcp-infra-499507 \
  --member="serviceAccount:github-actions-deployer@gcp-infra-499507.iam.gserviceaccount.com" \
  --role="roles/storage.admin" \
  --condition=None
```

`roles/storage.admin` covers both jobs the pipeline performs: read/write of
state objects and the lock object in the state bucket, and the full
create/get/update/delete lifecycle of the buckets it manages.

Both commands are idempotent.

### TODO: tighten before this project grows

`roles/storage.admin` is broader than Phase 1 needs. It includes
`storage.buckets.setIamPolicy` and `storage.objects.setIamPolicy`, so the CI
identity can grant access to any bucket in the project — a privilege
escalation path — and it can read objects in every bucket, not just the state
bucket.

Replace it with:

- a project-level custom role holding only
  `storage.buckets.{create,get,update,delete,list}`
- `roles/storage.objectUser` bound **only** to `gs://gcp-infra-499507-tfstate`

Note that `roles/storage.editor` is *not* a valid middle ground: it lacks
`storage.buckets.get` and `storage.buckets.update`, so OpenTofu cannot refresh
or modify a bucket it created.

### Verify

```bash
# Roles held by the deployer
gcloud projects get-iam-policy gcp-infra-499507 \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-actions-deployer@gcp-infra-499507.iam.gserviceaccount.com" \
  --format="value(bindings.role)"

# Audit: must never list a USER_MANAGED key
gcloud iam service-accounts keys list \
  --iam-account=github-actions-deployer@gcp-infra-499507.iam.gserviceaccount.com \
  --format="table(name.basename(),keyType)"
```

## 4. Workload Identity Federation

Lets GitHub Actions obtain short-lived GCP credentials without any stored key.

### 4a. Pool — a container for external identities

```bash
gcloud iam workload-identity-pools create github-pool \
  --project=gcp-infra-499507 \
  --location=global \
  --display-name="GitHub Actions" \
  --description="External identities from GitHub Actions OIDC"
```

### 4b. Provider — the trust configuration

```bash
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --project=gcp-infra-499507 \
  --location=global \
  --workload-identity-pool=github-pool \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_owner == 'pfuture17'"
```

The attribute condition is mandatory, not stylistic. Every GitHub repository on
the internet shares this one issuer, so a provider without a condition would
accept tokens from anybody's workflow.

Only mapped claims are visible to IAM. `attribute.ref` is mapped now so that
branch-scoped bindings are possible later without recreating the provider.

### 4c. Allow the repository to impersonate the service account

```bash
gcloud iam service-accounts add-iam-policy-binding \
  github-actions-deployer@gcp-infra-499507.iam.gserviceaccount.com \
  --project=gcp-infra-499507 \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/1063348389495/locations/global/workloadIdentityPools/github-pool/attribute.repository/pfuture17/github-cicd-gcp"
```

Two independent gates: the provider condition rejects any token outside the
`pfuture17` account, and this binding admits only the one repository.

Note the project **number** (`1063348389495`) in the principal — principals are
addressed by number, not by project ID.

### Verify

```bash
gcloud iam workload-identity-pools providers describe github-provider \
  --project=gcp-infra-499507 --location=global \
  --workload-identity-pool=github-pool \
  --format="yaml(name,state,oidc.issuerUri,attributeMapping,attributeCondition)"

gcloud iam service-accounts get-iam-policy \
  github-actions-deployer@gcp-infra-499507.iam.gserviceaccount.com \
  --format="yaml(bindings)"
```

### Caution

Pools, providers, and service accounts are **soft-deleted for 30 days**. Their
IDs cannot be reused during that window, so avoid delete-and-recreate cycles
with the same names.

## 5. Later: split plan and apply

A single deployer conflates read and write. The stronger pattern is two service
accounts: a read-only one bound to `attribute.repository`, and a write-capable
one bound to a specific branch such as `attribute.ref/refs/heads/main`. Because
GitHub sets the `ref` claim, a pull request cannot forge its way to apply — the
restriction is enforced by GCP IAM rather than by workflow YAML that a pull
request is free to edit.

When doing this, combine both attributes in the binding. A binding on
`attribute.ref` alone matches that branch in *any* repository added to the pool
later.
