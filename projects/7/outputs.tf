output "sns_topic_arn" {
  description = "ARN of the SNS topic ; use this to publish messages"
  value       = aws_sns_topic.main.arn
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.main.url
}

output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "lambda_function_name" {
  description = "Name of the Lambda function processing messages"
  value       = aws_lambda_function.main.function_name
}
