variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "messaging"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "max_receive_count" {
  description = "Number of times a message is received before being sent to the DLQ"
  type        = number
  default     = 3
}
