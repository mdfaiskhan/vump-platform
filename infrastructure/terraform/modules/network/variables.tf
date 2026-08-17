variable "environment_slug" {
  description = "AWS environment slug: dev, staging or prod. Never the APP_ENV key (naming-conventions.md §7.1)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment_slug)
    error_message = "environment_slug must be dev, staging or prod — not development/production (the APP_ENV keys)."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must not collide with the default VPC's 172.31.0.0/16."
  type        = string
}

variable "database_subnets" {
  description = "Map of availability zone to CIDR for the private database subnets. Aurora requires at least two AZs."
  type        = map(string)

  validation {
    condition     = length(var.database_subnets) >= 2
    error_message = "Aurora requires a DB subnet group spanning at least two availability zones."
  }
}
