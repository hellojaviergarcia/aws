# ============================================================
# DYNAMODB; A NoSQL database for storing tasks
# ============================================================

resource "aws_dynamodb_table" "todos" {
  name         = "${var.project_name}-table"
  billing_mode = "PAY_PER_REQUEST" # No provisioned capacity, pay-as-you-go
  hash_key     = "id"              # Primary key for each task

  attribute {
    name = "id"
    type = "S" # S = String
  }

  tags = {
    Name        = "${var.project_name}-table"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# IAM; Permissions required for Lambda to use DynamoDB and logs
# ============================================================

# The role that Lambda will assume when it runs
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# A policy based on the minimum necessary permissions (principle of least privilege)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Permission to write logs to CloudWatch
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # Permissions apply only to the DynamoDB table in this project
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",    # Create task
          "dynamodb:GetItem",    # Get assignment by ID
          "dynamodb:DeleteItem", # Delete task
          "dynamodb:Scan"        # List all tasks
        ]
        Resource = aws_dynamodb_table.todos.arn
      }
    ]
  })
}

# ============================================================
# LAMBDA; A function containing the API logic
# ============================================================

# Package the Python code into a ZIP file to upload it to Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_lambda_function" "todos" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "index.handler" # index.py file, handler() function

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # Detects changes in the code

  # Environment variable so that Lambda knows the name of the table
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todos.name
    }
  }

  timeout     = 10  # Maximum execution time in seconds
  memory_size = 128 # MB of memory allocated

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.todos.function_name}"
  retention_in_days = 7 # Retain logs for 7 days

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# API GATEWAY; Exposes the Lambda function as public HTTP endpoints
# ============================================================

resource "aws_apigatewayv2_api" "todos" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  # CORS: allows requests from any origin (useful for front-end applications)
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Deployment stage; groups endpoints under a base URL
resource "aws_apigatewayv2_stage" "todos" {
  api_id      = aws_apigatewayv2_api.todos.id
  name        = var.environment
  auto_deploy = true # Automatically refresh whenever the settings change

  tags = {
    Name        = "${var.project_name}-stage"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Integration between API Gateway and Lambda
resource "aws_apigatewayv2_integration" "todos" {
  api_id                 = aws_apigatewayv2_api.todos.id
  integration_type       = "AWS_PROXY" # Lambda receives the full event from API Gateway
  integration_uri        = aws_lambda_function.todos.invoke_arn
  payload_format_version = "2.0"
}

# API endpoints
# GET /todos ; list all tasks
resource "aws_apigatewayv2_route" "get_todos" {
  api_id    = aws_apigatewayv2_api.todos.id
  route_key = "GET /todos"
  target    = "integrations/${aws_apigatewayv2_integration.todos.id}"
}

# POST /todos ; create a new task
resource "aws_apigatewayv2_route" "post_todo" {
  api_id    = aws_apigatewayv2_api.todos.id
  route_key = "POST /todos"
  target    = "integrations/${aws_apigatewayv2_integration.todos.id}"
}

# DELETE /todos/{id} ; delete a task by ID
resource "aws_apigatewayv2_route" "delete_todo" {
  api_id    = aws_apigatewayv2_api.todos.id
  route_key = "DELETE /todos/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.todos.id}"
}

# Permission for API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.todos.execution_arn}/*/*"
}
