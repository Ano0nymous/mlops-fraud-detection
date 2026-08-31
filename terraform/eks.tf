module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Replaces "eksctl utils associate-iam-oidc-provider" - the module
  # creates the OIDC provider itself, and its outputs (oidc_provider_arn,
  # cluster_oidc_issuer_url) feed the IRSA roles in iam-irsa.tf and
  # iam-alb-controller.tf below.
  enable_irsa = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }

  # Replaces manually editing the aws-auth ConfigMap. Grants the CI role
  # (iam-github-oidc.tf) edit access scoped to just the mlops namespace -
  # not full cluster-admin - so a compromised CI token can't touch
  # kube-system or other namespaces.
  access_entries = {
    ci = {
      principal_arn = aws_iam_role.github_actions_ci.arn
      policy_associations = {
        edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = [var.k8s_namespace]
          }
        }
      }
    }
  }
}
