# Used as a prefix for all resource names (VPC, subnets, security groups, IAM role)
# to keep them identifiable and avoid conflicts across projects
variable "project_name" {
  description = "Project name, used as a prefix for all resource names"
  type        = string
  default     = "networking-security"
}

# Used in resource tags to identify the deployment environment
variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# /16 gives 65,536 IP addresses ; plenty of room to carve out multiple subnets.
# The 10.0.0.0/8 range is private (RFC 1918) and never routed on the public internet.
variable "vpc_cidr" {
  description = "CIDR block for the VPC ; defines the full private IP address space"
  type        = string
  default     = "10.0.0.0/16"
}

# /24 gives 256 IP addresses (251 usable ; AWS reserves 5 per subnet).
# Placed in us-east-1a ; resources here get a public IP and can reach the internet.
variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet ; must be a subset of vpc_cidr"
  type        = string
  default     = "10.0.1.0/24"
}

# Placed in us-east-1b ; resources here have no public IP and cannot be reached from the internet.
# Separating AZs provides fault tolerance if one availability zone goes down.
variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet ; must be a subset of vpc_cidr"
  type        = string
  default     = "10.0.2.0/24"
}
