# ============================================================
# RANDOM ID ; Ensures unique bucket names globally
# ============================================================

resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================
# S3 BUCKETS ; Raw data, processed data and Athena results
# ============================================================

# Raw bucket ; landing zone for incoming data
resource "aws_s3_bucket" "raw" {
  bucket = "${var.project_name}-raw-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-raw"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Layer       = "raw"
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket                  = aws_s3_bucket.raw.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Processed bucket ; cleaned and transformed data
resource "aws_s3_bucket" "processed" {
  bucket = "${var.project_name}-processed-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-processed"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Layer       = "processed"
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Athena results bucket ; stores query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-athena-results-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-athena-results"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Layer       = "athena"
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy on raw bucket ; move old data to cheaper storage
resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  depends_on = [aws_s3_bucket_versioning.raw]

  rule {
    id     = "archive-old-data"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# Upload sample CSV data to the raw bucket
resource "aws_s3_object" "sample_data" {
  bucket       = aws_s3_bucket.raw.id
  key          = "sales/2024/data.csv"
  source       = "${path.module}/data/sales.csv"
  content_type = "text/csv"
  etag         = filemd5("${path.module}/data/sales.csv")
}

# ============================================================
# IAM ; Permissions for Glue to access S3 and create catalog
# ============================================================

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "glue.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-glue-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Attach AWS managed policy for Glue service
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3" {
  name = "${var.project_name}-glue-s3-policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.raw.arn,
        "${aws_s3_bucket.raw.arn}/*",
        aws_s3_bucket.processed.arn,
        "${aws_s3_bucket.processed.arn}/*"
      ]
    }]
  })
}

# ============================================================
# GLUE ; Data catalog and crawler
# ============================================================

# Glue database ; logical container for tables in the catalog
resource "aws_glue_catalog_database" "main" {
  name        = replace("${var.project_name}_db", "-", "_")
  description = "Data lake catalog database for ${var.project_name}"
}

# Glue crawler ; scans S3 and infers schema automatically
resource "aws_glue_crawler" "sales" {
  name          = "${var.project_name}-sales-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.main.name
  description   = "Crawls raw sales data and updates the Glue catalog"

  s3_target {
    path = "s3://${aws_s3_bucket.raw.id}/sales/"
  }

  # Run daily at 2am UTC
  schedule = "cron(0 2 * * ? *)"

  schema_change_policy {
    delete_behavior = "LOG"     # Log schema changes, don't delete tables
    update_behavior = "UPDATE_IN_DATABASE"
  }

  tags = {
    Name        = "${var.project_name}-sales-crawler"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# ATHENA ; Query engine for the data lake
# ============================================================

# Athena workgroup ; isolates queries and controls costs
resource "aws_athena_workgroup" "main" {
  name        = "${var.project_name}-workgroup"
  description = "Workgroup for ${var.project_name} data lake queries"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/results/"

      # Encrypt query results at rest
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    # Limit query cost ; stop if bytes scanned exceeds 1 GB
    bytes_scanned_cutoff_per_query = 1073741824
  }

  tags = {
    Name        = "${var.project_name}-workgroup"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Named query ; example Athena query ready to run
resource "aws_athena_named_query" "sales_summary" {
  name        = "sales-summary"
  workgroup   = aws_athena_workgroup.main.id
  database    = aws_glue_catalog_database.main.name
  description = "Summarizes total sales by product"

  query = <<-SQL
    SELECT
      product,
      COUNT(*)        AS total_orders,
      SUM(amount)     AS total_revenue,
      AVG(amount)     AS avg_order_value
    FROM sales
    GROUP BY product
    ORDER BY total_revenue DESC;
  SQL
}
