variable "project_name" {
  description = "Project name, used to name all resources"
  type        = string
  default     = "bedrock-chatbot"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID to use for the chatbot"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "max_tokens" {
  description = "Maximum number of tokens in the model response"
  type        = number
  default     = 512
}
