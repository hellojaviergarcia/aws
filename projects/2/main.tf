# ============================================================
# DYNAMODB ; NoSQL database for storing tasks
# ============================================================

# DynamoDB is a fully managed serverless NoSQL database.
# PAY_PER_REQUEST means there is no provisioned capacity to manage ;
# AWS scales automatically and you only pay per read/write operation.
resource "aws_dynamodb_table" "todos" {
  name         = "${var.project_name}-table"
  billing_mode = "PAY_PER_REQUEST" # Scales automatically, no capacity planning needed
  hash_key     = "id"              # Partition key ; must be unique per item

  # Only attributes used as keys need to be declared here.
  # All other attributes are schema-less and defined at write time.
  attribute {
    name = "id"
    type = "S" # S = String, N = Number, B = Binary
  }

  tags = {
    Name        = "${var.project_name}-table"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# IAM ; Permissions for Lambda to use DynamoDB and CloudWatch
# ============================================================

# An IAM role is an identity that Lambda assumes at runtime.
# The assume_role_policy defines who is allowed to assume this role ;
# in this case, only the Lambda service itself.
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

# This policy follows the principle of least privilege ;
# Lambda is granted only the exact permissions it needs, nothing more.
# Two separate statements are used: one for CloudWatch Logs, one for DynamoDB.
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allows Lambda to create log groups/streams and write log events.
        # Without this, Lambda execution logs would not appear in CloudWatch.
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # Scoped to the specific DynamoDB table ARN ; not to all tables.
        # This means Lambda cannot read or write any other table in the account.
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",    # Used by create_todo()
          "dynamodb:GetItem",    # Available for future use
          "dynamodb:DeleteItem", # Used by delete_todo()
          "dynamodb:Scan"        # Used by get_todos() ; returns all items
        ]
        Resource = aws_dynamodb_table.todos.arn
      }
    ]
  })
}

# ============================================================
# LAMBDA ; Function containing the API business logic
# ============================================================

# Terraform cannot upload Python files directly to Lambda ;
# they must be packaged as a ZIP first. archive_file does this automatically.
# The output_base64sha256 hash is used to detect code changes between applies.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_lambda_function" "todos" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "index.handler" # Refers to the handler() function inside index.py

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256 # Forces re-deploy when code changes

  # Environment variables are injected at runtime and accessible via os.environ.
  # This avoids hardcoding the table name in the Python code.
  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.todos.name
    }
  }

  timeout     = 10  # Lambda will terminate the function after 10 seconds
  memory_size = 128 # 128 MB is the minimum and sufficient for simple CRUD operations

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch automatically creates a log group for Lambda,
# but defining it explicitly in Terraform lets us control retention
# and avoid orphaned log groups after terraform destroy.
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.todos.function_name}"
  retention_in_days = 7 # Logs older than 7 days are deleted automatically to reduce cost

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# API GATEWAY ; Exposes Lambda as public HTTP endpoints
# ============================================================

# API Gateway v2 (HTTP API) is used here instead of REST API (v1)
# because it is simpler, cheaper and has lower latency.
# It acts as the front door ; receives HTTP requests and forwards them to Lambda.
resource "aws_apigatewayv2_api" "todos" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  # CORS must be configured at the API level to allow browsers to make
  # cross-origin requests. Without this, frontend apps would be blocked
  # by the browser's same-origin policy.
  cors_configuration {
    allow_origins = ["*"]                              # Allow requests from any origin
    allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# A stage groups all routes under a base URL path (e.g. /prod/todos).
# auto_deploy = true means changes take effect immediately without a manual deployment.
resource "aws_apigatewayv2_stage" "todos" {
  api_id      = aws_apigatewayv2_api.todos.id
  name        = var.environment # Stage name becomes part of the URL: /prod/todos
  auto_deploy = true

  tags = {
    Name        = "${var.project_name}-stage"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# The integration connects API Gateway to Lambda using the AWS_PROXY type,
# which means the entire HTTP request (headers, body, path, query string)
# is forwarded as-is to the Lambda event object. payload_format_version 2.0
# is the modern format for HTTP APIs.
resource "aws_apigatewayv2_integration" "todos" {
  api_id                 = aws_apigatewayv2_api.todos.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.todos.invoke_arn
  payload_format_version = "2.0"
}

# Each route maps an HTTP method + path to the Lambda integration.
# API Gateway evaluates routes in order of specificity.

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
# The {id} is a path parameter ; it is accessible in Lambda via event["pathParameters"]["id"]
resource "aws_apigatewayv2_route" "delete_todo" {
  api_id    = aws_apigatewayv2_api.todos.id
  route_key = "DELETE /todos/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.todos.id}"
}

# This resource-based policy grants API Gateway permission to invoke Lambda.
# Without it, API Gateway would receive a 403 from Lambda even with the correct IAM role.
# source_arn scopes the permission to this specific API and all its stages and routes.
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.todos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.todos.execution_arn}/*/*" # */* = all stages and all routes
}
