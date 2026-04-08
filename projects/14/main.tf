# ============================================================
# RANDOM ID ; Ensures unique bucket names globally
# ============================================================

resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================
# S3 ; Primary bucket with cross-region replication to DR site
# ============================================================

resource "aws_s3_bucket" "primary" {
  bucket = "${var.project_name}-primary-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-primary"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Region      = "us-east-1"
  }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DR bucket in secondary region
resource "aws_s3_bucket" "dr" {
  provider = aws.secondary
  bucket   = "${var.project_name}-dr-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-dr"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Region      = "eu-west-1"
  }
}

resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.dr.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "dr" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.dr.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for S3 replication
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-replication-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "replication" {
  name = "${var.project_name}-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = "${aws_s3_bucket.dr.arn}/*"
      }
    ]
  })
}

# Cross-region replication from primary to DR
resource "aws_s3_bucket_replication_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication.arn

  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "replicate-all"
    status = "Enabled"
    filter {}

    destination {
      bucket        = aws_s3_bucket.dr.arn
      storage_class = "STANDARD_IA"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# ============================================================
# VPC PRIMARY ; Network for primary RDS
# ============================================================

resource "aws_vpc" "primary" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc-primary"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "primary_a" {
  vpc_id            = aws_vpc.primary.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "${var.project_name}-primary-subnet-a"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "primary_b" {
  vpc_id            = aws_vpc.primary.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name        = "${var.project_name}-primary-subnet-b"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_db_subnet_group" "primary" {
  name       = "${var.project_name}-primary-db-subnet"
  subnet_ids = [aws_subnet.primary_a.id, aws_subnet.primary_b.id]

  tags = {
    Name        = "${var.project_name}-primary-db-subnet"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "rds_primary" {
  name        = "${var.project_name}-sg-rds-primary"
  description = "Security group for primary RDS"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name        = "${var.project_name}-sg-rds-primary"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# RDS PRIMARY ; MySQL with Multi-AZ and automated backups
# ============================================================

resource "aws_db_instance" "primary" {
  identifier        = "${var.project_name}-primary-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "appdb"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.primary.name
  vpc_security_group_ids = [aws_security_group.rds_primary.id]

  multi_az                = true  # High availability within primary region
  backup_retention_period = 7     # Keep 7 days of automated backups
  backup_window           = "03:00-04:00"
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name        = "${var.project_name}-primary-db"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "primary"
  }
}

# ============================================================
# VPC DR ; Network for DR RDS read replica
# ============================================================

resource "aws_vpc" "dr" {
  provider             = aws.secondary
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc-dr"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "dr_a" {
  provider          = aws.secondary
  vpc_id            = aws_vpc.dr.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name        = "${var.project_name}-dr-subnet-a"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_subnet" "dr_b" {
  provider          = aws.secondary
  vpc_id            = aws_vpc.dr.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name        = "${var.project_name}-dr-subnet-b"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_db_subnet_group" "dr" {
  provider   = aws.secondary
  name       = "${var.project_name}-dr-db-subnet"
  subnet_ids = [aws_subnet.dr_a.id, aws_subnet.dr_b.id]

  tags = {
    Name        = "${var.project_name}-dr-db-subnet"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "rds_dr" {
  provider    = aws.secondary
  name        = "${var.project_name}-sg-rds-dr"
  description = "Security group for DR RDS read replica"
  vpc_id      = aws_vpc.dr.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  tags = {
    Name        = "${var.project_name}-sg-rds-dr"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# RDS READ REPLICA ; Cross-region replica in DR site
# ============================================================

resource "aws_db_instance" "dr" {
  provider   = aws.secondary
  identifier = "${var.project_name}-dr-db"

  # Read replica of the primary ; replicates data automatically
  replicate_source_db = aws_db_instance.primary.arn

  instance_class = "db.t3.micro"

  db_subnet_group_name   = aws_db_subnet_group.dr.name
  vpc_security_group_ids = [aws_security_group.rds_dr.id]

  # In a real DR scenario, promote this replica to standalone during failover
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-dr-db"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "read-replica-dr"
  }
}

# ============================================================
# ROUTE 53 ; Health check on primary region
# ============================================================

resource "aws_route53_health_check" "primary" {
  fqdn              = aws_db_instance.primary.address
  port              = 3306
  type              = "TCP"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name        = "${var.project_name}-health-check"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
