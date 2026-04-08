output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer ; open this in your browser"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.main.name
}

output "rds_endpoint" {
  description = "RDS instance endpoint ; use this to connect from EC2"
  value       = aws_db_instance.main.endpoint
}

output "rds_multi_az" {
  description = "Whether RDS is deployed in Multi-AZ mode"
  value       = aws_db_instance.main.multi_az
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
