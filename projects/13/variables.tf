variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "serverless-prod"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "cognito_user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
  default     = "serverless-prod-users"
}
