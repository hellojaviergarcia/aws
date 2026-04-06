variable "aws_region" {
  description = "AWS Region where the S3 bucket will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used to name resources"
  type        = string
  default     = "website"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
