# Aurora Serverless v2 (PostgreSQL), per Volume 4 Chapter 4.1's ADR-008.
#
# Reached exclusively through the RDS Data API (ADR-043). The cluster has no
# network path to anything: private subnets, no gateway, an empty security group.

resource "aws_db_subnet_group" "this" {
  name        = "vump-${var.environment_slug}-db-subnet-group"
  description = "Private subnets for the ${var.environment_slug} Aurora cluster."
  subnet_ids  = var.subnet_ids

  tags = {
    Name = "vump-${var.environment_slug}-db-subnet-group"
  }
}

# password_encryption is set explicitly rather than left to the engine default.
#
# The Data API "only supports scram-sha-256 for password encryption" on Aurora
# PostgreSQL 14 and higher. The engine already defaults to scram-sha-256 at these
# versions, so this pins a value the Data API depends on instead of inheriting
# one — a future parameter-group edit that set md5 would break every backend
# call, and the failure would appear as an authentication error far from its
# cause.
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "vump-${var.environment_slug}-aurora-pg16"
  family      = "aurora-postgresql${split(".", var.engine_version)[0]}"
  description = "Cluster parameters for vump-${var.environment_slug}. Pins password_encryption for the Data API."

  parameter {
    name  = "password_encryption"
    value = "scram-sha-256"
  }

  tags = {
    Name = "vump-${var.environment_slug}-aurora-pg16"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "vump-${var.environment_slug}-aurora"
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name

  # The Data API. Without this the cluster is unreachable, because nothing in
  # this configuration can open a network connection to it.
  enable_http_endpoint = true

  master_username = var.master_username

  # RDS creates and rotates the master password in Secrets Manager; no password
  # is ever expressed in Terraform, so none reaches the state file. This is the
  # documented exception to Mission 6.1's "create no Secrets Manager entries" —
  # the alternative is a password variable, which is worse on every axis.
  manage_master_user_password = true

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = var.security_group_ids
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  storage_encrypted       = true
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = (
    var.skip_final_snapshot ? null : "vump-${var.environment_slug}-aurora-final"
  )

  # Volume 4, Chapter 4.9 §1 places Aurora logs in CloudWatch alongside Lambda
  # and API Gateway.
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "vump-${var.environment_slug}-aurora"
  }
}

# One writer, no reader.
#
# The Data API "can only execute queries on writer instances in a DB cluster",
# even for reads — so a reader would serve no query this backend makes while
# billing a second instance's ACUs.
resource "aws_rds_cluster_instance" "writer" {
  identifier          = "vump-${var.environment_slug}-aurora-writer"
  cluster_identifier  = aws_rds_cluster.this.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.this.engine
  engine_version      = aws_rds_cluster.this.engine_version
  publicly_accessible = false

  tags = {
    Name = "vump-${var.environment_slug}-aurora-writer"
  }
}
