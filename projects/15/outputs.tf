output "raw_bucket_name" {
  description = "S3 raw data bucket name"
  value       = aws_s3_bucket.raw.id
}

output "processed_bucket_name" {
  description = "S3 processed data bucket name"
  value       = aws_s3_bucket.processed.id
}

output "athena_results_bucket_name" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "glue_database_name" {
  description = "Glue catalog database name"
  value       = aws_glue_catalog_database.main.name
}

output "glue_crawler_name" {
  description = "Glue crawler name"
  value       = aws_glue_crawler.sales.name
}

output "athena_workgroup_name" {
  description = "Athena workgroup name"
  value       = aws_athena_workgroup.main.name
}
