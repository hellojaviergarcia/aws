# ============================================================
# VPC; a virtual private network where all resources will be hosted
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Enable DNS resolution within the VPC
  enable_dns_hostnames = true # Assign DNS names to the instances

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# SUBNETS; Network segments within the VPC
# ============================================================

# Public subnet ; resources with direct internet access
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Instances are automatically assigned a public IP address

  tags = {
    Name        = "${var.project_name}-subnet-public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Private subnet ; resources without direct internet access
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-east-1b"

  tags = {
    Name        = "${var.project_name}-subnet-private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# INTERNET GATEWAY; Internet gateway for the VPC
# ============================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# ROUTE TABLES; Subnet routing rules
# ============================================================

# Public route table ; routes traffic to the internet via the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                    # All external traffic
    gateway_id = aws_internet_gateway.main.id   # It goes out via the Internet Gateway
  }

  tags = {
    Name        = "${var.project_name}-rt-public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Private routing table ; internal traffic only, no internet access
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-rt-private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Associate each route table with its corresponding subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ============================================================
# SECURITY GROUPS; Resource-level firewall
# ============================================================

# Public security group ; allows incoming HTTP, HTTPS and SSH traffic
resource "aws_security_group" "public" {
  name        = "${var.project_name}-sg-public"
  description = "Security group for resources in the public subnet"
  vpc_id      = aws_vpc.main.id

  # HTTP
  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH ; for administrative purposes only
  ingress {
    description = "SSH from the internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outgoing traffic is permitted
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Private security group ; only allows traffic from the public subnet
resource "aws_security_group" "private" {
  name        = "${var.project_name}-sg-private"
  description = "Security group for resources in the private subnet"
  vpc_id      = aws_vpc.main.id

  # Only accept traffic from the public security group
  ingress {
    description     = "Traffic from the public subnet"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public.id]
  }

  # All outgoing traffic is permitted
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg-private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# IAM; Role with least privilege, ready to be assigned
# ============================================================

# IAM role ; can be assumed by EC2 or Lambda
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = ["ec2.amazonaws.com", "lambda.amazonaws.com"] }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-app-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Minimal permissions policy ; logs only in CloudWatch
resource "aws_iam_role_policy" "app_policy" {
  name = "${var.project_name}-app-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Instance profile ; allows EC2 to assume the IAM role
resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app_role.name
}
