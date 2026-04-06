variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "storage"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "primary_region" {
  description = "Primary AWS region where the main bucket lives"
  type        = string
  default     = "us-east-1"
}

variable "replica_region" {
  description = "Secondary AWS region where the replica bucket lives"
  type        = string
  default     = "eu-west-1"
}
