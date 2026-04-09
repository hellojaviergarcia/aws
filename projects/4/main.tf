# ============================================================
# SNS TOPIC ; Notification channel for CloudWatch alarms
# ============================================================

# Amazon SNS (Simple Notification Service) is a pub/sub messaging service.
# CloudWatch alarms publish to this topic when they trigger or recover,
# and SNS forwards the message to all subscribers (in this case, an email address).
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# This subscription connects the SNS topic to an email address.
# AWS sends a confirmation email when this resource is created ;
# the subscription remains pending until the recipient clicks the confirmation link.
# No alerts will be delivered until the subscription is confirmed.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================
# IAM ; Permissions for Lambda to write logs to CloudWatch
# ============================================================

# IAM role that Lambda assumes at runtime.
# The assume_role_policy restricts who can assume the role ; only the Lambda service.
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

# Least-privilege policy ; grants Lambda only the permissions it needs
# to write execution logs to CloudWatch. No other AWS services are accessible.
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",  # Create the log group if it does not already exist
        "logs:CreateLogStream", # Create a log stream within the group
        "logs:PutLogEvents"     # Write log entries to the stream
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# ============================================================
# LAMBDA ; Simple function used as the monitored resource
# ============================================================

# Packages the Python source file into a ZIP before uploading to Lambda.
# source_code_hash ensures Terraform re-deploys the function whenever the code changes.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

# This Lambda function serves as the resource being monitored.
# It is intentionally simple ; its purpose is to generate logs and metrics
# that CloudWatch can track, alarm on and display in the dashboard.
resource "aws_lambda_function" "main" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "index.handler" # Refers to the handler() function inside index.py

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10  # Lambda terminates the function after 10 seconds
  memory_size = 128 # 128 MB is sufficient for a simple logging function

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# CLOUDWATCH ; Logs, metrics and alarms
# ============================================================

# Defining the log group explicitly in Terraform gives us control over retention.
# Without this, Lambda creates the log group automatically but with no retention policy,
# meaning logs accumulate indefinitely and incur storage costs.
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = 7 # Logs older than 7 days are automatically deleted

  tags = {
    Name        = "${var.project_name}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# This alarm monitors the Errors metric published by Lambda to CloudWatch.
# It triggers if Lambda throws 1 or more unhandled exceptions within a 5-minute window.
# treat_missing_data = "notBreaching" means periods with no invocations do not trigger the alarm ;
# this avoids false positives when the function simply has not been called.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name        = "${var.project_name}-lambda-errors"
  alarm_description = "Triggers when the Lambda function has errors"
  namespace         = "AWS/Lambda"   # AWS publishes Lambda metrics under this namespace
  metric_name       = "Errors"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name # Scope the alarm to this specific function
  }

  statistic           = "Sum"                            # Count the total number of errors in the period
  period              = 300                              # Evaluate over a 5-minute window
  evaluation_periods  = 1                                # Trigger after 1 consecutive breaching period
  threshold           = 1                                # Alarm if errors >= 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"                   # No invocations = no alarm

  alarm_actions = [aws_sns_topic.alerts.arn] # Send notification when alarm triggers
  ok_actions    = [aws_sns_topic.alerts.arn] # Send notification when alarm recovers

  tags = {
    Name        = "${var.project_name}-lambda-errors"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# This alarm monitors the Duration metric ; how long each Lambda invocation takes.
# It triggers if the average execution time exceeds 5 seconds (5000ms) in a 5-minute window.
# This is useful for detecting performance regressions or unexpected slowdowns
# before they become timeout errors (the Lambda timeout is set to 10 seconds).
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name        = "${var.project_name}-lambda-duration"
  alarm_description = "Triggers when the Lambda execution time exceeds 5 seconds"
  namespace         = "AWS/Lambda"
  metric_name       = "Duration"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  statistic           = "Average"                        # Use average duration, not sum
  period              = 300
  evaluation_periods  = 1
  threshold           = 5000                             # 5000 ms = 5 seconds
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

# CloudWatch dashboard ; a single-pane view of all Lambda metrics.
# Each widget is positioned on a 24-column grid using x/y/width/height.
# Three widgets span the full width (8 columns each = 24 total):
# invocations, errors and duration ; the three most important Lambda signals.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0  # Start at the left edge
        y      = 0  # First row
        width  = 8  # One third of the 24-column grid
        height = 6
        properties = {
          title   = "Lambda Invocations"
          region  = "us-east-1"
          period  = 300
          stat    = "Sum" # Total invocations in each 5-minute period
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.main.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8  # Second column
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Errors"
          region  = "us-east-1"
          period  = 300
          stat    = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.main.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16 # Third column
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Lambda Duration (ms)"
          region  = "us-east-1"
          period  = 300
          stat    = "Average" # Average duration gives a better signal than sum for latency
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.main.function_name]
          ]
        }
      }
    ]
  })
}
