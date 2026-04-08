# ============================================================
# S3 BUCKET ; Stores input files and analysis results
# ============================================================

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-bucket-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-bucket"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# IAM ; Permissions for Lambda to use AI services
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
        # Allow Lambda to read and write to S3
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      },
      {
        # Allow Lambda to use Rekognition for image analysis
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels",
          "rekognition:DetectText",
          "rekognition:DetectModerationLabels"
        ]
        Resource = "*"
      },
      {
        # Allow Lambda to use Comprehend for text analysis
        Effect = "Allow"
        Action = [
          "comprehend:DetectSentiment",
          "comprehend:DetectEntities",
          "comprehend:DetectKeyPhrases",
          "comprehend:DetectDominantLanguage"
        ]
        Resource = "*"
      },
      {
        # Allow Lambda to use Transcribe for audio transcription
        Effect = "Allow"
        Action = [
          "transcribe:StartTranscriptionJob",
          "transcribe:GetTranscriptionJob"
        ]
        Resource = "*"
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
# LAMBDA ; Orchestrates Rekognition, Comprehend and Transcribe
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

  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      TRANSCRIBE_LANGUAGE = var.transcribe_language
    }
  }

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# API GATEWAY ; Exposes the analysis pipeline as HTTP endpoint
# ============================================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  tags = {
    Name        = "${var.project_name}-stage"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_apigatewayv2_integration" "main" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
}

# POST /analyze/image ; analyze an image with Rekognition
resource "aws_apigatewayv2_route" "analyze_image" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /analyze/image"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

# POST /analyze/text ; analyze text with Comprehend
resource "aws_apigatewayv2_route" "analyze_text" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /analyze/text"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

# POST /analyze/audio ; transcribe audio with Transcribe
resource "aws_apigatewayv2_route" "analyze_audio" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /analyze/audio"
  target    = "integrations/${aws_apigatewayv2_integration.main.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
