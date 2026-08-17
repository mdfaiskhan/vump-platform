# Network for the Data API access path (ADR-043, Shape B).
#
# Aurora sits in private subnets with no route off the VPC and a security group
# that permits nothing. Under the Data API the backend never reaches the cluster
# over the network — rds-data is an HTTPS endpoint outside the VPC — so there is
# no internet gateway, no NAT gateway and no VPC-attached Lambda here.
#
# Volume 4, Chapter 4.9 §2 requires Aurora to be "never exposed to the public
# internet directly". A VPC with no gateway of any kind satisfies that by
# construction rather than by rule: there is no route to remove later.

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Required by RDS: without DNS hostnames the cluster endpoint does not resolve.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vump-${var.environment_slug}-vpc"
  }
}

# Private, and private by absence rather than by rule — no route table entry
# points anywhere but local, because no gateway exists to point at.
resource "aws_subnet" "database" {
  for_each = var.database_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "vump-${var.environment_slug}-db-${each.key}"
    Tier = "database"
  }
}

# An explicit route table, holding only the implicit local route.
#
# The VPC's main route table would do the same thing. This one exists so the
# "no egress" property is visible in the configuration and in a plan diff: a
# future route added to the main table would be silent, whereas adding one here
# is a reviewable change to a file named for the subnets it governs.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "vump-${var.environment_slug}-db-rt"
  }
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database.id
}

# The cluster's security group, with no rules at all.
#
# Volume 8, Chapter 8.4 §3 requires inbound "only from the Lambda functions' own
# security group". Under the Data API there is no Lambda security group to name,
# because no Lambda joins the VPC — so the narrowest correct expression of that
# rule is to permit nothing. This is not an unfinished rule; it is the rule with
# its subject removed.
#
# Consequence, recorded rather than discovered: nothing can open a Postgres
# connection to this cluster. Schema migration (Mission 6.3) must run through
# the Data API, or this group needs an ingress rule and a bastion — which would
# be a deliberate, reviewable change, not an oversight.
resource "aws_security_group" "aurora" {
  name        = "vump-${var.environment_slug}-aurora-sg"
  description = "Aurora cluster. No ingress: reached via the RDS Data API, never over the network."
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "vump-${var.environment_slug}-aurora-sg"
  }
}

# AWS creates a default security group with an allow-all-from-self ingress rule
# in every VPC, and it cannot be deleted. Adopting it with no rules empties it,
# so an instance launched without an explicit group inherits nothing.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "vump-${var.environment_slug}-default-sg-emptied"
  }
}
