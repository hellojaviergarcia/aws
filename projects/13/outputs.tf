output "api_url" {
  description = "Base URL of the API"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID ; use this to authenticate"
  value       = aws_cognito_user_pool_client.main.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB tasks table"
  value       = aws_dynamodb_table.tasks.name
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}
