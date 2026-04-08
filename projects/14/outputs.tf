output "primary_s3_bucket" {
  description = "Primary S3 bucket name (us-east-1)"
  value       = aws_s3_bucket.primary.id
}

output "dr_s3_bucket" {
  description = "DR S3 bucket name (eu-west-1)"
  value       = aws_s3_bucket.dr.id
}

output "primary_rds_endpoint" {
  description = "Primary RDS endpoint (us-east-1)"
  value       = aws_db_instance.primary.endpoint
}

output "dr_rds_endpoint" {
  description = "DR RDS read replica endpoint (eu-west-1)"
  value       = aws_db_instance.dr.endpoint
}

output "primary_rds_multi_az" {
  description = "Whether primary RDS is Multi-AZ"
  value       = aws_db_instance.primary.multi_az
}

output "route53_health_check_id" {
  description = "Route 53 health check ID monitoring the primary RDS"
  value       = aws_route53_health_check.primary.id
}
