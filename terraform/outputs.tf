output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "ecr_repository_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.mlflow_artifacts.id
}

output "rds_endpoint" {
  value = aws_db_instance.mlflow.address
}

output "mlflow_sa_role_arn" {
  value = aws_iam_role.mlflow_sa.arn
}

output "fastapi_sa_role_arn" {
  value = aws_iam_role.fastapi_sa.arn
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "github_actions_ci_role_arn" {
  description = "Set this as the GitHub repo secret AWS_CI_ROLE_ARN"
  value       = aws_iam_role.github_actions_ci.arn
}
