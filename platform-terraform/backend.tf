# Remote State Backend Configuration
# IMPORTANT: After running 'terraform apply' in terraform-backend/, update the bucket name below
# The bucket name will be: terraform-state-{YOUR_AWS_ACCOUNT_ID}
# Example: terraform-state-123456789012
#
# See terraform-backend/ or README.md for setup instructions

terraform {
  backend "s3" {
    bucket         = "YOUR-TERRAFORM-STATE-BUCKET-NAME"
    key            = "devsecops-demo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
