# Used as a prefix for all resource names (DynamoDB table, Lambda, API Gateway)
# Change this if you deploy multiple instances of this project in the same account
variable "project_name" {
  description = "Project name, used as a prefix for all resource names"
  type        = string
  default     = "todo-api"
}

# Used in resource tags to identify the deployment environment.
# Also used as the API Gateway stage name, which becomes part of the API URL:
# https://xxxx.execute-api.us-east-1.amazonaws.com/{environment}/todos
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
