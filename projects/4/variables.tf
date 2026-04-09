# Used as a prefix for all resource names (Lambda, SNS, CloudWatch alarms, dashboard)
# to keep them identifiable and avoid conflicts across projects
variable "project_name" {
  description = "Project name, used as a prefix for all resource names"
  type        = string
  default     = "monitoring"
}

# Used in resource tags to identify the deployment environment
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# SNS will send an email to this address when an alarm triggers or recovers.
# After deploying, you must confirm the subscription from your inbox ;
# AWS sends a confirmation email before any alerts are delivered.
variable "alert_email" {
  description = "Email address where CloudWatch alerts will be sent via SNS"
  type        = string
  default     = "your-email@example.com"
}
