variable "project_name" {
  description = "Project name, used to name resources"
  type        = string
  default     = "todo-api"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
