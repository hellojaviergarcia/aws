output "api_url" {
  description = "API base URL"
  value       = "${aws_apigatewayv2_stage.todos.invoke_url}/todos"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.todos.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.todos.function_name
}
