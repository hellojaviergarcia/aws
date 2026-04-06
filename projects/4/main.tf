# ============================================================
# SNS TOPIC ; Notification channel for alarms
# ============================================================

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Topic subscription ; sends alerts to the configured email
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# IAM ; Permissions for Lambda to write logs
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
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# ============================================================
# LAMBDA ; Simple function used as the monitored resource
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

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# CLOUDWATCH ; Logs, metrics and alarms
# ============================================================

# Log group ; stores Lambda execution logs
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 7 # Retain logs for 7 days to reduce costs

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Error alarm ; triggers if Lambda fails 1 or more times within 5 minutes
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name        = "${var.project_name}-lambda-errors"
  alarm_description = "Triggers when the Lambda function has errors"
  namespace         = "AWS/Lambda"
  metric_name       = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  statistic           = "Sum"
  period              = 300  # 5 minute window
  evaluation_periods  = 1    # Evaluate 1 period before triggering
  threshold           = 1    # Trigger if there is 1 or more errors
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching" # No data = no alarm

  alarm_actions = [aws_sns_topic.alerts.arn] # Notify by email when triggered
  ok_actions    = [aws_sns_topic.alerts.arn] # Notify also when recovered

  tags = {
    Name        = "${var.project_name}-lambda-errors"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Duration alarm ; triggers if Lambda takes more than 5 seconds
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name        = "${var.project_name}-lambda-duration"
  alarm_description = "Triggers when the Lambda execution time exceeds 5 seconds"
  namespace         = "AWS/Lambda"
  metric_name       = "Duration"
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5000 # 5000 ms = 5 seconds
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-lambda-duration"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# CloudWatch dashboard ; unified view of Lambda metrics
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Lambda Invocations"
          region = "us-east-1"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.main.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = "us-east-1"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.main.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Lambda Duration (ms)"
          region = "us-east-1"
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.main.function_name]
          ]
        }
      }
    ]
  })
}
