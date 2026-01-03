# Terraform State Backend Outputs

output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_lock.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.terraform_lock.arn
}

output "backend_config" {
  description = "Backend configuration for other projects"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "your-project-name/terraform.tfstate"
        region         = "${var.region}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
      }
    }
  EOT
}
