variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "fraud-detector"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "cluster_name" {
  description = "Must match EKS_CLUSTER in .github/workflows/*.yml"
  type        = string
  default     = "fraud-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "node_instance_types" {
  description = "The old eksctl runbook used t3.micro - that's tight once kubelet, CNI, and the mlflow/fastapi pods are all fighting for the same 2GB. t3.medium is a safer floor."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "s3_bucket_name" {
  description = "S3 bucket names are globally unique across ALL AWS accounts - change this if it's taken"
  type        = string
  default     = "my-mlflow-bucket67678"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "mlflowdb"
}

variable "db_username" {
  type    = string
  default = "mlflow_user"
}

variable "db_password" {
  description = "Never put a real value here or in any .tf file. Set it via `export TF_VAR_db_password=...` or a gitignored terraform.auto.tfvars."
  type        = string
  sensitive   = true
}

variable "github_org" {
  description = "GitHub org or username that owns the repo - used to scope the OIDC trust condition so only your repo can assume the CI role"
  type        = string
}

variable "github_repo" {
  description = "Repo name, without the org prefix"
  type        = string
}

variable "k8s_namespace" {
  type    = string
  default = "mlops"
}
