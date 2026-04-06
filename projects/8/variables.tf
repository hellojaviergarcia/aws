variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "database"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "ttl_days" {
  description = "Number of days before an item expires and is automatically deleted"
  type        = number
  default     = 30
}
