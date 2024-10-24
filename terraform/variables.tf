variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  nullable    = false
}

variable "environment" {
  description = "The environment for the deployment (e.g., production, staging)"
  type        = string
  nullable    = false
}

variable "prefix" {
  description = "A prefix for naming resources"
  type        = string
  nullable    = false
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  nullable    = false
}
variable "deployment_role_arn" {
  description = "The ARN of the IAM role to assume for deployment"
  type        = string
  sensitive   = true
  nullable    = false
}

variable "domain_name" {
  description = "The domain name for the ACM certificate"
  type        = string
  nullable    = false
}