locals {
  ecr_repos = ["fraud-detector", "fraud-train", "mlflow-server"]
}

resource "aws_ecr_repository" "this" {
  for_each = toset(local.ecr_repos)
  name     = each.value

  # MUTABLE because app-cicd.yml pushes both a git-sha tag and `:latest` on
  # every build, and IMMUTABLE would reject the second `:latest` push.
  # Switch to IMMUTABLE once you drop the `:latest` tag in favor of
  # sha-only deploys.
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "expire_untagged" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 14 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 14
      }
      action = { type = "expire" }
    }]
  })
}
