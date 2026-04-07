output "api_url" {
  description = "Base URL of the multilingual processing API"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "translate_url" {
  description = "Endpoint to detect and translate text"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/translate"
}

output "analyze_url" {
  description = "Endpoint to translate and analyze text"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/analyze"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}
