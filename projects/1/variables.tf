# The AWS region is hardcoded in providers.tf ; this variable is kept for
# reference and potential future use (e.g. passing to resource tags)
variable "aws_region" {
  description = "AWS region where the S3 bucket will be deployed"
  type        = string
  default     = "us-east-1"
}

# Used as a prefix for all resource names to keep them identifiable
# and avoid conflicts across projects
variable "project_name" {
  description = "Project name, used as a prefix for all resource names"
  type        = string
  default     = "website"
}

# Used in resource tags to identify the deployment environment
# Useful when multiple environments share the same AWS account
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
