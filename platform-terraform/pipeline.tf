resource "aws_codecommit_repository" "app" {
  repository_name = "${local.name_prefix}-repo"
  description     = var.codepipeline_repository_description
  default_branch  = "main"
}

resource "aws_codebuild_project" "app" {
  name          = "${local.name_prefix}-build"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.app.repository_url
    }

    environment_variable {
      name  = "COMPLIANCE_BUCKET"
      value = aws_s3_bucket.compliance.bucket
    }

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.artifacts.bucket
    }

    environment_variable {
      name  = "CLUSTER_NAME"
      value = aws_eks_cluster.this.name
    }

    environment_variable {
      name  = "DEPLOY_ROLE_ARN"
      value = aws_iam_role.eks_deploy.arn
    }

    environment_variable {
      name  = "K8S_NAMESPACE"
      value = "demo"
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "TARGET_GROUP_ARN"
      value = aws_lb_target_group.app.arn
    }

    environment_variable {
      name  = "ALB_SECURITY_GROUP_ID"
      value = aws_security_group.alb.id
    }

    environment_variable {
      name  = "ALB_DNS_NAME"
      value = aws_lb.main.dns_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.root}/../app-cicd/buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${local.name_prefix}-build"
      stream_name = "codebuild"
      status      = "ENABLED"
    }
  }

  tags = local.tags
}

resource "aws_codepipeline" "app" {
  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName     = aws_codecommit_repository.app.repository_name
        BranchName         = aws_codecommit_repository.app.default_branch
        PollForSourceChanges = "true"
      }
    }
  }

  stage {
    name = "BuildDeploy"

    action {
      name             = "BuildDeploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.app.name
      }
    }
  }

  tags = local.tags
}
