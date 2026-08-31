# This is the "GitHub OIDC -> AWS role" step the previous README told you
# to set up by hand. Trusts GitHub's OIDC issuer scoped to this repo, so
# Actions can assume the role without any long-lived AWS access keys
# sitting in GitHub secrets.

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Scoped to this repo, any branch/workflow. Tighten to
    # "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main" if
    # you want only main-branch pushes able to assume this role - PRs from
    # forks or other branches would then be unable to deploy.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  name               = "github-actions-ci"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

# ECR push/pull for the repos this project actually builds
data "aws_iam_policy_document" "ci_ecr" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [for r in aws_ecr_repository.this : r.arn]
  }
}

resource "aws_iam_policy" "ci_ecr" {
  name   = "github-actions-ci-ecr"
  policy = data.aws_iam_policy_document.ci_ecr.json
}

resource "aws_iam_role_policy_attachment" "ci_ecr" {
  role       = aws_iam_role.github_actions_ci.name
  policy_arn = aws_iam_policy.ci_ecr.arn
}

# Only DescribeCluster is needed for `aws eks update-kubeconfig` - the
# actual in-cluster kubectl permissions come from the EKS access entry in
# eks.tf, not from an IAM policy.
data "aws_iam_policy_document" "ci_eks" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_policy" "ci_eks" {
  name   = "github-actions-ci-eks-describe"
  policy = data.aws_iam_policy_document.ci_eks.json
}

resource "aws_iam_role_policy_attachment" "ci_eks" {
  role       = aws_iam_role.github_actions_ci.name
  policy_arn = aws_iam_policy.ci_eks.arn
}
