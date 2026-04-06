variable "project_name" {
  description = "Project name, used to name resources"
  type        = string
  default     = "monitoring"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "alert_email" {
  description = "Email address where CloudWatch alerts will be sent"
  type        = string
  default     = "your-email@example.com"
}
