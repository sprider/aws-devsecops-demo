variable "project" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "devsecops"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "demo"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "principal-sa"
}

variable "demo_id" {
  description = "Unique demo identifier"
  type        = string
  default     = "aws-devsecops"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
  default     = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
  default     = [
    "10.20.101.0/24",
    "10.20.102.0/24"
  ]
}

variable "codebuild_image" {
  description = "CodeBuild container image"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "eks_version" {
  description = "EKS version - 1.34 is the latest stable version"
  type        = string
  default     = "1.34"
}

variable "codepipeline_repository_description" {
  description = "Description for the demo CodeCommit repository"
  type        = string
  default     = "DevSecOps demo application repository"
}

variable "allowed_cidr_ingress" {
  description = "CIDR block allowed to reach the ALB"
  type        = string
  default     = "0.0.0.0/0"
}

variable "cognito_user_email" {
  description = "Optional seed user email for Cognito"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for ALB HTTPS listener. If empty, a self-signed certificate is generated for demo purposes."
  type        = string
  default     = ""
}

variable "enable_dr_replication" {
  description = "Enable cross-region replication for disaster recovery"
  type        = bool
  default     = false
}

variable "dr_region" {
  description = "Disaster recovery region for S3 replication"
  type        = string
  default     = "us-west-2"
}

variable "enable_waf" {
  description = "Enable AWS WAF for the application load balancer"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications. Leave empty to skip email subscription."
  type        = string
  default     = ""
}

variable "blocked_countries" {
  description = "List of ISO 3166-1 alpha-2 country codes to block via WAF geo-blocking. Empty list disables geo-blocking."
  type        = list(string)
  default     = []
}
