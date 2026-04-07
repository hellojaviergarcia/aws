variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "content-analysis"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "transcribe_language" {
  description = "Language code for Amazon Transcribe"
  type        = string
  default     = "en-US"
}
