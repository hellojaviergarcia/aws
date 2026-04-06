output "cloudfront_url" {
  description = "URL of the chatbot web interface"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "api_url" {
  description = "URL of the chat API endpoint"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/chat"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "bedrock_model_id" {
  description = "Bedrock model used by the chatbot"
  value       = var.bedrock_model_id
}
