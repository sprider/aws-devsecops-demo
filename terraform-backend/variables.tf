# Variables for Terraform State Backend

variable "region" {
  description = "AWS region for the state backend resources"
  type        = string
  default     = "us-east-1"
}

variable "enable_version_expiration" {
  description = "Enable automatic expiration of old state file versions"
  type        = bool
  default     = false
}

variable "version_expiration_days" {
  description = "Number of days to keep old state file versions"
  type        = number
  default     = 90
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB table"
  type        = bool
  default     = false
}
