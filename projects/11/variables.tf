variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "multilingual"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "target_language" {
  description = "Default target language code for translation"
  type        = string
  default     = "en"
}
