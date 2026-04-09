# ============================================================
# RANDOM ID ; Ensures globally unique bucket names
# ============================================================

# S3 bucket names must be globally unique across all AWS accounts and regions.
# This random suffix prevents name collisions when multiple people deploy this project.
resource "random_id" "suffix" {
  byte_length = 4 # Generates 4 bytes = 8 hex characters (e.g. "a1b2c3d4")
}

# ============================================================
# PRIMARY BUCKET ; Main storage bucket in us-east-1
# ============================================================

resource "aws_s3_bucket" "primary" {
  bucket = "${var.project_name}-primary-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-primary"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Blocks all forms of public access at the bucket level.
# Objects are private by default ; no presigned URLs or public policies are allowed.
# All access must go through authenticated AWS API calls.
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls       = true # Reject requests that include a public ACL
  block_public_policy     = true # Reject bucket policies that grant public access
  ignore_public_acls      = true # Ignore any existing public ACLs on objects
  restrict_public_buckets = true # Block cross-account access to publicly accessible buckets
}

# Versioning keeps a full history of every object in the bucket.
# Each time an object is overwritten or deleted, the previous version is retained.
# This protects against accidental overwrites and enables point-in-time recovery.
# Note: versioning cannot be disabled once enabled ; only suspended.
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle policies automate the movement of objects between storage classes
# based on age. This reduces storage costs without manual intervention.
# The depends_on ensures versioning is enabled before the lifecycle rule is applied ;
# noncurrent_version rules only work on versioned buckets.
resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "storage-tiering"
    status = "Enabled"

    filter {} # Empty filter applies the rule to all objects in the bucket

    # S3 storage class progression by age:
    # Day 0-29:   S3 Standard       ; high availability, high cost, frequent access
    # Day 30-89:  S3 Standard-IA    ; same durability, lower cost, retrieval fee applies
    # Day 90-179: S3 Glacier IR     ; archival storage, millisecond retrieval, very low cost
    # Day 180+:   Permanently deleted ; objects are removed from the bucket entirely

    transition {
      days          = 30
      storage_class = "STANDARD_IA" # ~40% cheaper than Standard for infrequent access
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR" # ~68% cheaper than Standard, retrieved in milliseconds
    }

    expiration {
      days = 180 # Objects older than 180 days are permanently deleted
    }

    # Old (noncurrent) versions follow their own lifecycle to control version storage costs.
    # After 30 days in Standard, old versions move to Standard-IA.
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    # Old versions are permanently deleted after 90 days ; only the current version is kept.
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# ============================================================
# REPLICA BUCKET ; Secondary bucket in eu-west-1
# ============================================================

# The provider = aws.replica attribute routes this resource to the secondary provider,
# creating the bucket in eu-west-1 instead of the default us-east-1.
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

# Versioning is a hard requirement for cross-region replication.
# AWS replication works at the object version level ; if versioning is disabled
# on either the source or destination bucket, replication will fail.
resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================
# IAM ; Permissions for S3 to replicate objects across regions
# ============================================================

# S3 needs an IAM role to authenticate when writing replicated objects
# to the destination bucket in another region.
# The assume_role_policy allows the S3 service to assume this role.
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

# This policy follows the principle of least privilege ; three separate statements
# grant exactly the permissions S3 needs at each step of the replication process:
# 1. Read the replication configuration and list the source bucket
# 2. Read object versions and their metadata from the source bucket
# 3. Write (replicate) objects, deletions and tags to the destination bucket
resource "aws_iam_role_policy" "replication" {
  name = "${var.project_name}-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Step 1 ; Read the replication configuration from the source bucket
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration", # Read the replication rules defined on the bucket
          "s3:ListBucket"                   # List objects in the source bucket
        ]
        Resource = aws_s3_bucket.primary.arn # Scoped to the primary bucket only
      },
      {
        # Step 2 ; Read the object versions that need to be replicated
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication", # Read the object content for a specific version
          "s3:GetObjectVersionAcl",            # Read the ACL of the object version
          "s3:GetObjectVersionTagging"         # Read the tags of the object version
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*" # All objects inside the primary bucket
      },
      {
        # Step 3 ; Write the replicated objects to the destination bucket
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject", # Write the object to the replica bucket
          "s3:ReplicateDelete", # Replicate delete markers to keep buckets in sync
          "s3:ReplicateTags"    # Copy object tags to the replica
        ]
        Resource = "${aws_s3_bucket.replica.arn}/*" # All objects inside the replica bucket
      }
    ]
  })
}

# ============================================================
# REPLICATION ; Cross-region replication configuration
# ============================================================

# This resource attaches the replication rules to the primary bucket.
# depends_on = versioning ensures versioning is fully enabled before
# the replication configuration is applied ; AWS requires this ordering.
resource "aws_s3_bucket_replication_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  role   = aws_iam_role.replication.arn

  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {} # Empty filter replicates all objects ; no prefix or tag filtering

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD_IA" # Store replicas in Standard-IA to reduce cost
                                    # Replicas are accessed less frequently than originals
    }

    # Replicating delete markers keeps the two buckets in sync when objects are deleted.
    # Without this, deleted objects in the primary would still exist in the replica.
    delete_marker_replication {
      status = "Enabled"
    }
  }
}
