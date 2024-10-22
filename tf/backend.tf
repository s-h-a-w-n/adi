terraform {
  backend "s3" {
    bucket         = "adi-sft-production-tf-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/adi-sft-production-tf-backend"
    role_arn       = "arn:aws:iam::678309485142:role/adi-sft-production-tf-backend-role"
  }
}