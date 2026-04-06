output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value       = aws_subnet.private.id
}

output "public_security_group_id" {
  description = "Public security group ID"
  value       = aws_security_group.public.id
}

output "private_security_group_id" {
  description = "Private security group ID"
  value       = aws_security_group.private.id
}

output "iam_role_arn" {
  description = "IAM role ARN ; use this to assign it to EC2 or Lambda"
  value       = aws_iam_role.app_role.arn
}

output "iam_instance_profile_name" {
  description = "Instance profile name ; use this when launching an EC2 instance"
  value       = aws_iam_instance_profile.app_profile.name
}
