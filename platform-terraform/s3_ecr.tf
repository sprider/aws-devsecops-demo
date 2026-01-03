resource "aws_kms_key" "artifacts" {
  description             = "KMS key for pipeline artifact bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowS3ArtifactsBucket"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:s3:::${local.name_prefix}-artifacts"
          }
        }
      },
      {
        Sid    = "AllowCodeBuildCodePipeline"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.codebuild.arn,
            aws_iam_role.codepipeline.arn
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${local.name_prefix}-artifacts-kms" })
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/${local.name_prefix}-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}

resource "aws_kms_key" "compliance" {
  description             = "KMS key for compliance evidence bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "AllowS3ComplianceBucket"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:s3:::${local.name_prefix}-compliance"
          }
        }
      },
      {
        Sid    = "AllowCodeBuildCodePipeline"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.codebuild.arn,
            aws_iam_role.codepipeline.arn
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${local.name_prefix}-compliance-kms" })
}

resource "aws_kms_alias" "compliance" {
  name          = "alias/${local.name_prefix}-compliance"
  target_key_id = aws_kms_key.compliance.key_id
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name_prefix}-artifacts"
  force_destroy = true

  tags = merge(local.tags, {
    Name         = "${local.name_prefix}-artifacts"
    Classification = "build-artifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.artifacts.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "artifact-retention"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket" "compliance" {
  bucket        = "${local.name_prefix}-compliance"
  force_destroy = true

  tags = merge(local.tags, {
    Name           = "${local.name_prefix}-compliance"
    Classification = "compliance"
  })
}

resource "aws_s3_bucket_versioning" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.compliance.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "compliance" {
  bucket = aws_s3_bucket.compliance.id

  rule {
    id     = "compliance-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2557
    }
  }
}

resource "aws_s3_bucket" "compliance_replica" {
  count        = var.enable_dr_replication ? 1 : 0
  provider     = aws.dr
  bucket       = "${local.name_prefix}-compliance-${var.dr_region}"
  force_destroy = true

  tags = merge(local.tags, {
    Name           = "${local.name_prefix}-compliance-dr"
    Classification = "compliance-dr"
  })
}

resource "aws_s3_bucket_versioning" "compliance_replica" {
  count    = var.enable_dr_replication ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.compliance_replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "compliance_replication" {
  count = var.enable_dr_replication ? 1 : 0
  name  = "${local.name_prefix}-compliance-repl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "compliance_replication" {
  count = var.enable_dr_replication ? 1 : 0
  name  = "${local.name_prefix}-compliance-repl"
  role  = aws_iam_role.compliance_replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.compliance.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.compliance.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:GetObjectVersionForReplication"
        ]
        Resource = "${aws_s3_bucket.compliance_replica[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:PutObjectTagging"
        ]
        Resource = aws_s3_bucket.compliance_replica[0].arn
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "compliance" {
  count      = var.enable_dr_replication ? 1 : 0
  bucket     = aws_s3_bucket.compliance.id
  role       = aws_iam_role.compliance_replication[0].arn
  depends_on = [aws_s3_bucket_versioning.compliance, aws_s3_bucket_versioning.compliance_replica]

  rule {
    id     = "dr-replication"
    status = "Enabled"

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.compliance_replica[0].arn
      storage_class = "STANDARD"
    }
  }
}

resource "aws_ecr_repository" "app" {
  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ecr"
  })
}
