locals {
  vpc_cidr_block = var.vpc_cidr_block

  private_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr_block, 3, 0),
    cidrsubnet(local.vpc_cidr_block, 3, 1)
  ]

  public_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr_block, 3, 2),
    cidrsubnet(local.vpc_cidr_block, 3, 3)
  ]

  database_subnet_cidrs = [
    cidrsubnet(local.vpc_cidr_block, 3, 4),
    cidrsubnet(local.vpc_cidr_block, 3, 5)
  ]

  private_subnet_names  = ["${var.prefix}-private-1", "${var.prefix}-private-2"]
  public_subnet_names   = ["${var.prefix}-public-1", "${var.prefix}-public-2"]
  database_subnet_names = ["${var.prefix}-database-1", "${var.prefix}-database-2"]

  tags = {
    ManagedBy   = "Terraform"
    Environment = var.environment
    Application = var.prefix
  }
}