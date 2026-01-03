resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.name_prefix}/cluster"
  retention_in_days = 30

  tags = local.tags
}

resource "aws_eks_cluster" "this" {
  name     = "${local.name_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = values(aws_subnet.private)[*].id
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.allowed_cidr_ingress]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  access_config {
    authentication_mode = "API"
  }

  depends_on = [
    aws_cloudwatch_log_group.eks,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy
  ]

  tags = local.tags
}

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "${local.name_prefix}-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate_pod.arn
  subnet_ids             = values(aws_subnet.private)[*].id

  selector {
    namespace = "kube-system"
  }

  tags = local.tags
}

resource "aws_eks_fargate_profile" "demo" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "${local.name_prefix}-demo"
  pod_execution_role_arn = aws_iam_role.fargate_pod.arn
  subnet_ids             = values(aws_subnet.private)[*].id

  selector {
    namespace = "demo"
  }

  tags = local.tags
}

resource "aws_eks_access_entry" "deploy" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.eks_deploy.arn
  type          = "STANDARD"
}

resource "aws_eks_access_entry" "codebuild" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.codebuild.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deploy_admin" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.eks_deploy.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "codebuild_reader" {
  cluster_name  = aws_eks_cluster.this.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_role.codebuild.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_update = "PRESERVE"

  tags = local.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_update = "PRESERVE"

  tags = local.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_fargate_profile.kube_system]

  tags = local.tags
}
