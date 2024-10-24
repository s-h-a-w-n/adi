provider "aws" {
  region = var.region

  assume_role {
    role_arn = var.deployment_role_arn
  }

  default_tags {
    tags = local.tags
  }
}