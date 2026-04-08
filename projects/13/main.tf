# ============================================================
# DYNAMODB ; Tasks table with GSI
# ============================================================

resource "aws_dynamodb_table" "tasks" {
  name         = "${var.project_name}-tasks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "taskId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "taskId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # GSI ; allows querying tasks by status
  global_secondary_index {
    name            = "status-index"
    hash_key        = "userId"
    range_key       = "status"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-tasks"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# COGNITO ; User Pool for authentication
# ============================================================

resource "aws_cognito_user_pool" "main" {
  name = var.cognito_user_pool_name

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # Auto-verify email on sign-up
  auto_verified_attributes = ["email"]

  # Required attributes for sign-up
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
  }

  tags = {
    Name        = var.cognito_user_pool_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# App client ; allows the frontend to interact with the User Pool
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Allow username/password auth flow
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Token validity
  access_token_validity  = 1   # 1 hour
  id_token_validity      = 1   # 1 hour
  refresh_token_validity = 30  # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# ============================================================
# IAM ; Permissions for Lambda
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
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.tasks.arn,
          "${aws_dynamodb_table.tasks.arn}/index/*"
        ]
      },
      {
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
# LAMBDA ; Task management business logic
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
      TABLE_NAME = aws_dynamodb_table.tasks.name
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
# API GATEWAY ; HTTP API with Cognito JWT authorizer
# ============================================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
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

# Cognito JWT authorizer ; validates tokens on every request
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  name             = "${var.project_name}-cognito-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.main.id]
    issuer   = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

resource "aws_apigatewayv2_integration" "main" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.main.invoke_arn
  payload_format_version = "2.0"
}

# GET /tasks ; list tasks for the authenticated user
resource "aws_apigatewayv2_route" "get_tasks" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /tasks"
  target             = "integrations/${aws_apigatewayv2_integration.main.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# POST /tasks ; create a task for the authenticated user
resource "aws_apigatewayv2_route" "post_task" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /tasks"
  target             = "integrations/${aws_apigatewayv2_integration.main.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# DELETE /tasks/{taskId} ; delete a task for the authenticated user
resource "aws_apigatewayv2_route" "delete_task" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "DELETE /tasks/{taskId}"
  target             = "integrations/${aws_apigatewayv2_integration.main.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
