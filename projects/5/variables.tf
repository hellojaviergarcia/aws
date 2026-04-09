# Used as a prefix for all resource names (primary bucket, replica bucket, IAM role)
# to keep them identifiable and avoid conflicts across projects
variable "project_name" {
  description = "Project name, used as a prefix for all resource names"
  type        = string
  default     = "storage"
}

# Used in resource tags to identify the deployment environment
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Kept for reference and tagging ; the actual region is hardcoded in providers.tf
# because Terraform provider aliases require static region values
variable "primary_region" {
  description = "Primary AWS region where the main bucket lives"
  type        = string
  default     = "us-east-1"
}

# Same as above ; kept for reference and tagging purposes
variable "replica_region" {
  description = "Secondary AWS region where the replica bucket lives"
  type        = string
  default     = "eu-west-1"
}
