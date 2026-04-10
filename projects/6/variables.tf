# Used as a prefix for all resource names (VPC, subnets, ASG, launch template, alarms)
variable "project_name" {
  description = "Project name, used as a prefix for all resource names"
  type        = string
  default     = "compute"
}

# Used in resource tags to identify the deployment environment
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# t3.micro is Free Tier eligible and sufficient for demonstration purposes.
# In production, choose an instance type based on workload CPU and memory requirements.
variable "instance_type" {
  description = "EC2 instance type ; must be Free Tier eligible (e.g. t3.micro)"
  type        = string
  default     = "t3.micro"
}

# The ASG will never scale below this number regardless of CPU metrics.
# Setting min_size = 1 ensures at least one instance is always running.
variable "min_size" {
  description = "Minimum number of instances the Auto Scaling Group will maintain"
  type        = number
  default     = 1
}

# The ASG will never exceed this number even if CPU remains high.
# This acts as a cost cap ; scale-up policies cannot go beyond this limit.
variable "max_size" {
  description = "Maximum number of instances the Auto Scaling Group can scale up to"
  type        = number
  default     = 3
}

# The number of instances the ASG launches immediately after creation.
# The ASG will scale up or down from this starting point based on CPU alarms.
variable "desired_capacity" {
  description = "Initial number of instances launched when the ASG is created"
  type        = number
  default     = 1
}
