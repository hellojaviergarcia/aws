output "api_url" {
  description = "Base URL of the content analysis API"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for input files and results"
  value       = aws_s3_bucket.main.id
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "analyze_image_url" {
  description = "Endpoint to analyze images with Rekognition"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/analyze/image"
}

output "analyze_text_url" {
  description = "Endpoint to analyze text with Comprehend"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/analyze/text"
}

output "analyze_audio_url" {
  description = "Endpoint to transcribe audio with Transcribe"
  value       = "${aws_apigatewayv2_stage.main.invoke_url}/analyze/audio"
}
