# ============================================================
# DATA ; Fetch the latest Amazon Linux 2023 AMI dynamically
# ============================================================

# Instead of hardcoding an AMI ID (which is region-specific and changes with updates),
# we use a data source to always fetch the latest Amazon Linux 2023 AMI at plan time.
# most_recent = true ensures we get the newest available version.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Only trust AMIs published by AWS

  # Filter by name pattern ; al2023 is Amazon Linux 2023, x86_64 is the architecture
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  # Only consider AMIs that are currently available (not deprecated or pending)
  filter {
    name   = "state"
    values = ["available"]
  }
}

# ============================================================
# VPC ; Dedicated network for this project
# ============================================================

# A dedicated VPC is created instead of relying on the account's default VPC.
# This makes the project fully self-contained and replicable in any AWS account,
# even those where the default VPC has been deleted.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # 65,536 available IP addresses
  enable_dns_support   = true           # Enables DNS resolution within the VPC
  enable_dns_hostnames = true           # Assigns DNS hostnames to instances with public IPs

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# The Internet Gateway (IGW) allows resources in public subnets to send
# and receive traffic from the internet. Without it, no traffic can flow
# in or out of the VPC, even if instances have public IPs.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Three public subnets ; one per Availability Zone (us-east-1a, 1b, 1c).
# Spreading instances across multiple AZs ensures the ASG can maintain capacity
# even if one AZ becomes unavailable.
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"   # 256 IPs (251 usable ; AWS reserves 5)
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true             # Instances automatically receive a public IP

  tags = {
    Name        = "${var.project_name}-subnet-a"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-subnet-b"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-subnet-c"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# A single route table with a default route (0.0.0.0/0) pointing to the IGW.
# This table is shared across all three public subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                 # All traffic not destined for the VPC CIDR
    gateway_id = aws_internet_gateway.main.id # is forwarded to the Internet Gateway
  }

  tags = {
    Name        = "${var.project_name}-rt"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Associate the route table with each subnet so traffic from instances
# in those subnets is routed correctly to the internet.
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# SECURITY GROUP ; Stateful firewall for EC2 instances
# ============================================================

# Security groups are stateful ; return traffic is automatically allowed
# without needing an explicit outbound rule for each inbound rule.
# This security group allows HTTP (port 80) for the web server
# and SSH (port 22) for administration.
# Note: in production, SSH should be restricted to a known IP range.
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg"
  description = "Security group for EC2 instances in the Auto Scaling Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet ; serves the Apache web page"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH for administration ; restrict to known IP in production"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic ; instances need internet access for yum updates
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"           # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# LAUNCH TEMPLATE ; Reusable EC2 instance configuration
# ============================================================

# A Launch Template defines everything about an EC2 instance: AMI, instance type,
# network configuration, user data and tags. The ASG uses this template to launch
# new instances whenever it needs to scale up or replace an unhealthy instance.
resource "aws_launch_template" "main" {
  name          = "${var.project_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id # Resolved dynamically at plan time
  instance_type = var.instance_type

  # User data is a shell script that runs once when the instance first boots.
  # base64encode() is required ; EC2 expects user data in base64 format.
  # This script installs Apache and creates a simple HTML page showing the hostname,
  # which makes it easy to verify which instance served a given request.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Instance $(hostname) is running</h1>" > /var/www/html/index.html
  EOF
  )

  network_interfaces {
    associate_public_ip_address = true                    # Instance gets a public IP on launch
    security_groups             = [aws_security_group.ec2.id]
  }

  # tag_specifications applies tags to the EC2 instance itself (not the launch template).
  # propagate_at_launch in the ASG handles tagging instances launched by the ASG.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-instance"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }

  tags = {
    Name        = "${var.project_name}-lt"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# AUTO SCALING GROUP ; Manages EC2 instance count automatically
# ============================================================

# The ASG maintains between min_size and max_size instances at all times.
# It distributes instances across the three subnets (and therefore three AZs)
# using vpc_zone_identifier, which provides fault tolerance across AZs.
resource "aws_autoscaling_group" "main" {
  name             = "${var.project_name}-asg"
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # Spread instances across all three subnets ; one per AZ
  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id
  ]

  # Always use the latest version of the launch template.
  # If you update the launch template, the ASG will use the new version
  # for any new instances it launches.
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  # Rolling instance refresh replaces existing instances with new ones
  # when the launch template changes. min_healthy_percentage = 50 means
  # at least half the instances must remain healthy during the refresh ;
  # this prevents downtime during updates.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Tags with propagate_at_launch = true are applied to every EC2 instance
  # launched by this ASG, making it easy to identify them in the console.
  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

# ============================================================
# SCALING POLICIES ; Define how the ASG scales up and down
# ============================================================

# ChangeInCapacity adds or removes a fixed number of instances.
# scaling_adjustment = 1 means "add 1 instance" when triggered.
# cooldown = 300 prevents additional scaling actions for 5 minutes after a scale event,
# giving the new instance time to start up and handle traffic before another decision is made.
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1    # Add 1 instance per trigger
  cooldown               = 300  # Wait 5 minutes before allowing another scale action
}

# scaling_adjustment = -1 means "remove 1 instance" when triggered.
# The same cooldown prevents aggressive scale-down during brief CPU dips.
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1   # Remove 1 instance per trigger
  cooldown               = 300
}

# ============================================================
# CLOUDWATCH ALARMS ; Monitor CPU and trigger scaling policies
# ============================================================

# This alarm evaluates the average CPU utilisation across all instances in the ASG
# over two consecutive 5-minute periods. Using evaluation_periods = 2 prevents
# a single spike from triggering a scale-up ; CPU must be consistently high.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  alarm_description   = "Triggers scale up when CPU exceeds 70%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300  # Evaluate over 5-minute windows
  evaluation_periods  = 2    # Must breach for 2 consecutive periods (10 minutes total)
  threshold           = 70   # Trigger when average CPU >= 70%
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name # Scope to this ASG only
  }

  alarm_actions = [aws_autoscaling_policy.scale_up.arn] # Execute the scale-up policy
}

# Same logic as the high CPU alarm, but in reverse.
# CPU must be consistently low for 10 minutes before a scale-down is triggered,
# preventing premature removal of instances during temporary load drops.
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  alarm_description   = "Triggers scale down when CPU drops below 30%"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 30   # Trigger when average CPU <= 30%
  comparison_operator = "LessThanOrEqualToThreshold"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_down.arn] # Execute the scale-down policy
}
