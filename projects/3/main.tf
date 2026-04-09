# ============================================================
# VPC ; Isolated private network for all resources
# ============================================================

# A VPC is a logically isolated section of the AWS cloud.
# All resources in this project (subnets, security groups, instances) live inside this VPC.
# No traffic can enter or leave the VPC unless explicitly allowed via routes and security groups.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Allows resources inside the VPC to resolve DNS names
  enable_dns_hostnames = true # Assigns a DNS hostname to instances with public IPs

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# SUBNETS ; Network segments within the VPC
# ============================================================

# The public subnet hosts resources that need to be reachable from the internet
# (e.g. load balancers, bastion hosts, NAT gateways).
# map_public_ip_on_launch = true means instances launched here automatically
# get a public IP ; required for direct internet connectivity.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-subnet-public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# The private subnet hosts resources that must not be directly reachable from the internet
# (e.g. databases, application servers, Lambda functions in a VPC).
# Resources here can only receive traffic from other resources inside the VPC.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-east-1b" # Different AZ from the public subnet for fault tolerance

  tags = {
    Name        = "${var.project_name}-subnet-private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# INTERNET GATEWAY ; Enables internet access for the VPC
# ============================================================

# The Internet Gateway (IGW) is the component that allows resources
# in the public subnet to send and receive traffic from the internet.
# Without an IGW attached to the VPC, no traffic can flow in or out,
# even if a resource has a public IP address.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# ROUTE TABLES ; Traffic routing rules per subnet
# ============================================================

# The public route table has a default route (0.0.0.0/0) pointing to the IGW.
# This means any traffic destined for an address outside the VPC CIDR
# is sent to the internet gateway ; giving the subnet internet access.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # Catch-all route for all non-VPC traffic
    gateway_id = aws_internet_gateway.main.id  # Forward it to the Internet Gateway
  }

  tags = {
    Name        = "${var.project_name}-rt-public"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# The private route table has no internet route ; only the implicit local route exists.
# The local route (10.0.0.0/16) is added automatically by AWS and allows
# resources within the VPC to communicate with each other.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-rt-private"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Route table associations link a subnet to a route table.
# Every subnet must be associated with exactly one route table.
# If no explicit association exists, AWS uses the VPC's main route table.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# ============================================================
# SECURITY GROUPS ; Resource-level stateful firewall
# ============================================================

# Security groups are stateful ; if inbound traffic is allowed,
# the response is automatically allowed outbound, and vice versa.
# They operate at the resource level (per instance, per Lambda, per RDS),
# unlike NACLs which operate at the subnet level.

# The public security group allows inbound HTTP, HTTPS and SSH from anywhere.
# This is appropriate for a load balancer or bastion host in the public subnet.
# Note: in production, SSH (port 22) should be restricted to a known IP range,
# not open to 0.0.0.0/0.
resource "aws_security_group" "public" {
  name        = "${var.project_name}-sg-public"
  description = "Security group for resources in the public subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH for administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to a known IP in production
  }

  # protocol = "-1" means all protocols, from_port/to_port = 0 means all ports.
  # Allowing all outbound is standard practice ; the risk is inbound, not outbound.
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

# The private security group demonstrates the principle of least privilege:
# it only accepts traffic that originates from resources in the public security group.
# Using security_groups (instead of cidr_blocks) means the rule is automatically
# updated if the public SG's instances change ; no manual IP management needed.
resource "aws_security_group" "private" {
  name        = "${var.project_name}-sg-private"
  description = "Security group for resources in the private subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "All traffic from the public security group only"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public.id] # Only public SG members can reach private resources
  }

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
# IAM ; Least-privilege role ready to be assumed by EC2 or Lambda
# ============================================================

# An IAM role is an identity with a defined set of permissions.
# Unlike IAM users, roles are not tied to a person ; they are assumed
# by services (EC2, Lambda) that need to call other AWS APIs.
# The assume_role_policy defines which services are allowed to assume this role.
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        # Both EC2 and Lambda can assume this role ; useful for a mixed architecture
        # where the same permissions are needed in both compute layers
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

# This policy grants only CloudWatch Logs permissions ; the bare minimum
# needed for any compute resource to write execution logs.
# Additional permissions (e.g. S3, DynamoDB) would be added in separate
# statements as the application's needs grow.
resource "aws_iam_role_policy" "app_policy" {
  name = "${var.project_name}-app-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",  # Create the log group if it doesn't exist
          "logs:CreateLogStream", # Create a log stream within the group
          "logs:PutLogEvents"     # Write log entries to the stream
        ]
        Resource = "arn:aws:logs:*:*:*" # Applies to all log groups in all regions
      }
    ]
  })
}

# An instance profile is a container for an IAM role that EC2 can use.
# EC2 cannot assume an IAM role directly ; it must go through an instance profile.
# Lambda, by contrast, uses the role ARN directly without a profile.
resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app_role.name
}
