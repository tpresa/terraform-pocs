terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    # EMR on EKS is the only variant that touches the cluster's data plane: the
    # namespace and RBAC that authorize EMR to launch job pods are Kubernetes
    # objects, not AWS resources.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    # Used once, to read the OIDC issuer's CA thumbprint for the IAM provider.
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# The kubernetes provider authenticates as the same AWS principal running
# Terraform, using a short-lived token minted for the cluster. It is configured
# from the cluster resource's attributes (not a data source) so a single apply
# can both create the cluster and lay down its namespace/RBAC. The values are
# unknown until the cluster exists, which Terraform resolves by deferring the
# provider's first use until then.
data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.this.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# ---------------------------------------------------------------------------
# EKS cluster
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.name}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # API_AND_CONFIG_MAP enables access entries (used below to map EMR's
  # service-linked role into the cluster). bootstrap_*_admin_permissions gives
  # the creating principal cluster-admin so the kubernetes provider can create
  # the namespace and RBAC in this same apply.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

# ---------------------------------------------------------------------------
# Managed node group (runs the Spark driver/executor pods)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-eks-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_count
    min_size     = var.node_count
    max_size     = var.node_count
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ---------------------------------------------------------------------------
# OIDC provider — lets job pods assume the execution role via IRSA
# ---------------------------------------------------------------------------

locals {
  # The IAM trust-policy condition keys are the issuer URL without its scheme.
  oidc_issuer = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

# ---------------------------------------------------------------------------
# Grant EMR access to the namespace
#
# EMR operates the cluster as its service-linked role. That role is mapped to a
# Kubernetes group via an access entry, and the group is granted exactly the
# permissions EMR needs (the rules below are the set AWS documents) inside the
# target namespace only.
# ---------------------------------------------------------------------------

resource "aws_iam_service_linked_role" "emr_containers" {
  aws_service_name = "emr-containers.amazonaws.com"
}

resource "aws_eks_access_entry" "emr" {
  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = aws_iam_service_linked_role.emr_containers.arn
  kubernetes_groups = ["emr-containers"]
  type              = "STANDARD"
}

resource "kubernetes_namespace_v1" "emr" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_role_v1" "emr" {
  metadata {
    name      = "emr-containers"
    namespace = kubernetes_namespace_v1.emr.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "services", "configmaps", "events", "pods", "pods/log"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "patch", "delete", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
  }
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
  }
}

resource "kubernetes_role_binding_v1" "emr" {
  metadata {
    name      = "emr-containers"
    namespace = kubernetes_namespace_v1.emr.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.emr.metadata[0].name
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = "emr-containers"
  }
}

# ---------------------------------------------------------------------------
# Job execution role
#
# Assumed by the per-job service accounts EMR generates in the namespace
# (named emr-containers-sa-*). The StringLike on :sub scopes the trust to those
# accounts; `aws emr-containers update-role-trust-policy` can tighten it to the
# exact, role-specific service account name once the virtual cluster exists.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "job_exec_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:emr-containers-sa-*"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "job_exec" {
  name               = "${var.name}-emr-eks-job"
  assume_role_policy = data.aws_iam_policy_document.job_exec_assume.json
}

# Read scripts/input and write output to one bucket, plus push logs to
# CloudWatch. Catalog-backed jobs would also need glue:* on the relevant tables.
data "aws_iam_policy_document" "job_exec" {
  statement {
    sid = "ReadWriteJobBucket"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.job_data_bucket}",
      "arn:aws:s3:::${var.job_data_bucket}/*",
    ]
  }
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/emr-containers/*"]
  }
}

resource "aws_iam_role_policy" "job_exec" {
  name   = "${var.name}-emr-eks-job"
  role   = aws_iam_role.job_exec.name
  policy = data.aws_iam_policy_document.job_exec.json
}

# ---------------------------------------------------------------------------
# Virtual cluster — the EMR-side handle to the EKS namespace
# ---------------------------------------------------------------------------

resource "aws_emrcontainers_virtual_cluster" "this" {
  name = var.name

  container_provider {
    id   = aws_eks_cluster.this.name
    type = "EKS"
    info {
      eks_info {
        namespace = var.namespace
      }
    }
  }

  # Registration validates that EMR can operate in the namespace, so the RBAC
  # and access-entry mapping must already be in place.
  depends_on = [
    kubernetes_role_binding_v1.emr,
    aws_eks_access_entry.emr,
  ]
}
