variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "data-lake"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
