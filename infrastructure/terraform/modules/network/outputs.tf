output "vpc_id" {
  description = "ID of the environment VPC."
  value       = aws_vpc.this.id
}

output "database_subnet_ids" {
  description = "IDs of the private database subnets, for the DB subnet group."
  value       = [for s in aws_subnet.database : s.id]
}

output "aurora_security_group_id" {
  description = "ID of the Aurora security group. Carries no rules by design."
  value       = aws_security_group.aurora.id
}
