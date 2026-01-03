data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_string" "suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  name_prefix = "${var.project}-${var.environment}-${random_string.suffix.result}"
  vpc_cidr    = var.vpc_cidr
  tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    DemoID      = var.demo_id
    ManagedBy   = "Terraform"
  }
  common_iam_tags = local.tags
}
