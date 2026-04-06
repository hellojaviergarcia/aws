output "sns_topic_arn" {
  description = "ARN of the SNS topic used for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  description = "Name of the monitored Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "lambda_errors_alarm_name" {
  description = "Name of the Lambda errors alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_errors.alarm_name
}

output "lambda_duration_alarm_name" {
  description = "Name of the Lambda duration alarm"
  value       = aws_cloudwatch_metric_alarm.lambda_duration.alarm_name
}
