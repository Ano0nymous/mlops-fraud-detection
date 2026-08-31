# Terraform - infra for the fraud-detector project

Replaces every manual step in the old `resources-setup` runbook (S3 bucket,
RDS, EKS cluster, OIDC provider, IAM roles/policies, ALB controller
install) with state-tracked infrastructure. One `terraform apply` gets you
from nothing to a cluster ready for `kubectl apply -f k8s/`.

## Read this before you run anything

Your account (`471932414173`) already has resources with these exact
names running - the S3 bucket, the `fraud-cluster` EKS cluster, the
`mlflow-postgres` RDS instance. This config is written to **create new
resources with those same names**, so running it as-is against the same
account will fail with "already exists" errors.

Pick one:
- **Fresh environment** (recommended for trying this out) - change
  `cluster_name`, `s3_bucket_name`, and the RDS `identifier` in `rds.tf` to
  something new, or point `AWS_PROFILE` at a different account/region.
- **Adopt your existing infra into Terraform** - use `terraform import` for
  each resource before your first `apply` (the EKS cluster, the S3 bucket,
  the RDS instance, each IAM role). This is the right long-term move but
  it's a resource-by-resource process - do it once, carefully, not as part
  of a normal apply.

## What's here

| File | Provisions |
|---|---|
| `vpc.tf` | VPC, public/private subnets across 2 AZs, single NAT gateway |
| `eks.tf` | EKS cluster + managed node group, OIDC provider (`enable_irsa`), EKS access entry for the CI role |
| `ecr.tf` | 3 repos: `fraud-detector`, `fraud-train`, `mlflow-server` |
| `s3.tf` | Versioned, encrypted, fully-private MLflow artifacts bucket |
| `rds.tf` | Postgres in private subnets, reachable only from EKS nodes (the old runbook had this publicly accessible) |
| `iam-irsa.tf` | `mlflow-s3-access` and `fraud-api-s3-readonly` roles - same names your k8s manifests already reference |
| `iam-alb-controller.tf` | IRSA role for the AWS Load Balancer Controller |
| `iam-github-oidc.tf` | GitHub OIDC provider + CI role - this is `AWS_CI_ROLE_ARN` |
| `helm.tf` | Creates the `mlops` namespace, installs the ALB controller |

## Setup

```bash
cd terraform
terraform init

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: github_org, github_repo

export TF_VAR_db_password="something-strong-and-not-committed-anywhere"

terraform plan     # read it - this creates real, billed AWS resources
terraform apply
```

Takes 15-20 minutes, mostly waiting on the EKS control plane and node
group.

## After apply

```bash
terraform output configure_kubectl   # run the command it prints
kubectl apply -f ../k8s/00-namespace.yaml    # if not using helm.tf's namespace
kubectl apply -f ../k8s/
```

Copy these outputs into GitHub repo secrets (Settings > Secrets > Actions),
which is what `app-cicd.yml` and `train-promote.yml` read:

| GitHub secret | terraform output |
|---|---|
| `AWS_CI_ROLE_ARN` | `github_actions_ci_role_arn` |
| `AWS_ACCOUNT_ID` | `aws_account_id` |
| `AWS_REGION` | (the `aws_region` var you set) |
| `DB_USERNAME` | (the `db_username` var - default `mlflow_user`) |
| `DB_PASSWORD` | the `TF_VAR_db_password` value you exported |
| `DB_NAME` | (the `db_name` var - default `mlflowdb`) |
| `DB_HOST` | `rds_endpoint` |

## Notes

- Node instance type was bumped from the old runbook's `t3.micro` to
  `t3.medium` - `t3.micro` is genuinely too tight once kubelet, the CNI,
  and your actual pods are all competing for ~2GB.
- ECR repos are `MUTABLE` because the CI workflow re-pushes `:latest` on
  every build. Switch to `IMMUTABLE` once you're deploying by sha only.
- `terraform destroy` will tear down the RDS instance, EKS cluster, and
  VPC. There's a final RDS snapshot on destroy, but nothing else is
  recoverable - don't run this against anything with real data without
  thinking about it first.
