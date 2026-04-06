# ============================================================
# RANDOM ID ; Ensures unique bucket names globally
# ============================================================

resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================
# PRIMARY BUCKET ; Main storage bucket
# ============================================================

resource "aws_s3_bucket" "primary" {
  bucket = "${var.project_name}-primary-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-primary"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Block all public access ; objects are private by default
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning ; keeps previous versions of every object
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle policy ; automatically moves objects to cheaper storage classes
resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "storage-tiering"
    status = "Enabled"

    filter {}

    # Day 0 → S3 Standard (default, high availability)
    # Day 30 → S3 Standard-IA (infrequent access, 40% cheaper)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Day 90 → S3 Glacier Instant Retrieval (archival, 68% cheaper than Standard)
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    # Day 180 → objects are permanently deleted
    expiration {
      days = 180
    }

    # Clean up old versions after 90 days
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ============================================================
# REPLICA BUCKET ; Secondary bucket in a different region
# ============================================================

resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "${var.project_name}-replica-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-replica"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning must be enabled on the replica bucket for replication to work
resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# IAM ; Permissions for S3 to replicate objects
# ============================================================

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
        # Allow reading objects from the primary bucket
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        # Allow writing objects to the replica bucket
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.replica.arn}/*"
      }
    ]
  })
}

# ============================================================
# REPLICATION ; Cross-region replication configuration
# ============================================================

resource "aws_s3_bucket_replication_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication.arn

  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD_IA" # Replica stored in cheaper storage class
    }

    delete_marker_replication {
      status = "Enabled" # Replicate deletions to keep buckets in sync
    }
  }
}
