output "cloudfront_url" {
  description = "Public website URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket created"
  value       = aws_s3_bucket.website.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (useful for invalidating the cache)"
  value       = aws_cloudfront_distribution.website.id
}
