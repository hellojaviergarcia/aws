# ============================================================
# DYNAMODB TABLE ; NoSQL table with advanced features
# ============================================================

resource "aws_dynamodb_table" "main" {
  name         = "${var.project_name}-table"
  billing_mode = "PAY_PER_REQUEST" # No provisioned capacity, pay per request
  hash_key     = "pk"              # Partition key
  range_key    = "sk"              # Sort key ; enables range queries

  # Primary key attributes
  attribute {
    name = "pk"
    type = "S" # String
  }

  attribute {
    name = "sk"
    type = "S"
  }

  # GSI attributes
  attribute {
    name = "gsi1pk"
    type = "S"
  }

  attribute {
    name = "gsi1sk"
    type = "S"
  }

  # Global Secondary Index ; allows querying by a different key
  global_secondary_index {
    name            = "gsi1"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL" # Include all attributes in the index
  }

  # TTL ; automatically deletes items after a set expiration time
  ttl {
    attribute_name = "expires_at" # Unix timestamp ; item is deleted after this value
    enabled        = true
  }

  # Streams ; captures every change to the table (insert, update, delete)
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # Capture both before and after state

  # Point-in-time recovery ; allows restoring the table to any point in the last 35 days
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-table"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# IAM ; Permissions for Lambda to read and write to DynamoDB
# ============================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow Lambda to read and write to DynamoDB
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.main.arn,
          "${aws_dynamodb_table.main.arn}/index/*" # Include GSI access
        ]
      },
      {
        # Allow Lambda to write logs to CloudWatch
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

# ============================================================
# LAMBDA ; Demonstrates DynamoDB operations
# ============================================================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_lambda_function" "main" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "index.handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.main.name
      TTL_DAYS   = var.ttl_days
    }
  }

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
