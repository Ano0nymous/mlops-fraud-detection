# Role names are deliberately identical to what's already hardcoded in
# k8s/01-serviceaccounts.yaml ("mlflow-s3-access", "fraud-api-s3-readonly")
# so applying this Terraform doesn't require touching the k8s manifests -
# the ServiceAccount annotations just start resolving to real roles.

# --- mlflow-sa: full read/write on the artifacts bucket ---

data "aws_iam_policy_document" "mlflow_sa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:mlflow-sa"]
    }
  }
}

resource "aws_iam_role" "mlflow_sa" {
  name               = "mlflow-s3-access"
  assume_role_policy = data.aws_iam_policy_document.mlflow_sa_assume.json
}

data "aws_iam_policy_document" "mlflow_s3" {
  statement {
    actions = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      aws_s3_bucket.mlflow_artifacts.arn,
      "${aws_s3_bucket.mlflow_artifacts.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "mlflow_s3" {
  name   = "mlflow-s3-access-policy"
  policy = data.aws_iam_policy_document.mlflow_s3.json
}

resource "aws_iam_role_policy_attachment" "mlflow_sa" {
  role       = aws_iam_role.mlflow_sa.name
  policy_arn = aws_iam_policy.mlflow_s3.arn
}

# --- fastapi-sa: read-only on the same bucket (the earlier fix) ---

data "aws_iam_policy_document" "fastapi_sa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:fastapi-sa"]
    }
  }
}

resource "aws_iam_role" "fastapi_sa" {
  name               = "fraud-api-s3-readonly"
  assume_role_policy = data.aws_iam_policy_document.fastapi_sa_assume.json
}

data "aws_iam_policy_document" "fastapi_s3_readonly" {
  statement {
    actions = ["s3:ListBucket", "s3:GetObject"]
    resources = [
      aws_s3_bucket.mlflow_artifacts.arn,
      "${aws_s3_bucket.mlflow_artifacts.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "fastapi_s3_readonly" {
  name   = "fraud-api-s3-readonly-policy"
  policy = data.aws_iam_policy_document.fastapi_s3_readonly.json
}

resource "aws_iam_role_policy_attachment" "fastapi_sa" {
  role       = aws_iam_role.fastapi_sa.name
  policy_arn = aws_iam_policy.fastapi_s3_readonly.arn
}
