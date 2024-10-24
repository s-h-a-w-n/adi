#!/bin/sh -e

# Ensure required commands are available
command -v aws >/dev/null 2>&1 || { echo >&2 "aws CLI is required but it's not installed. Aborting."; exit 1; }
command -v sudo >/dev/null 2>&1 || { echo >&2 "sudo is required but it's not installed. Aborting."; exit 1; }

# Global Variables
REGION="us-east-1"
ACCOUNT_ID="678309485142"
ENVIRONMENT="production"
PREFIX="adi-sft"
LOGFILE="/var/log/${PREFIX}/bootstrap-backend.log"

# Ensure log directory and file exist with correct permissions
if [ ! -d "$(dirname $LOGFILE)" ]; then
  echo "[$(date)] INFO: Creating log directory: $(dirname $LOGFILE)" | sudo tee -a "$LOGFILE"
  sudo mkdir -p "$(dirname $LOGFILE)"
  sudo chmod 755 "$(dirname $LOGFILE)"
fi
echo "[$(date)] INFO: log directory exists: $(dirname $LOGFILE)" | sudo tee -a "$LOGFILE"

if [ ! -f "$LOGFILE" ]; then
  echo "[$(date)] INFO: Creating log file: $LOGFILE" | sudo tee -a "$LOGFILE"
  sudo touch "$LOGFILE"
  sudo chmod 644 "$LOGFILE"
fi
echo "[$(date)] INFO: log file exists: $LOGFILE" | sudo tee -a "$LOGFILE"

BUCKET_NAME="${PREFIX}-${ENVIRONMENT}-tf-state"
IAM_ROLE_NAME="${PREFIX}-${ENVIRONMENT}-tf-backend-role"
IAM_POLICY_NAME="${PREFIX}-${ENVIRONMENT}-tf-backend-policy"
KMS_ALIAS="alias/${PREFIX}-${ENVIRONMENT}-tf-backend"
IAM_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
TAGS="Key=Project,Value=${PREFIX} Key=Environment,Value=${ENVIRONMENT} Key=ProvisionedBy,Value=Terraform"

DEPLOYMENT_ROLE_NAME="${PREFIX}-deployment-role"
DEPLOYMENT_POLICY_NAME="${PREFIX}-deployment-policy"

# Function to create S3 bucket
create_s3_bucket() {
  if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "[$(date)] INFO: S3 bucket ${BUCKET_NAME} already exists." | sudo tee -a "$LOGFILE"
  else
    echo "[$(date)] INFO: Creating S3 bucket for Terraform state: ${BUCKET_NAME}" | sudo tee -a "$LOGFILE"
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" --create-bucket-configuration LocationConstraint="${REGION}"
    echo "[$(date)] INFO: Enabling versioning on S3 bucket" | sudo tee -a "$LOGFILE"
    aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" --versioning-configuration Status=Enabled
    echo "[$(date)] INFO: Tagging S3 bucket" | sudo tee -a "$LOGFILE"
    aws s3api put-bucket-tagging --bucket "${BUCKET_NAME}" --tagging "TagSet=[{Key=Project,Value=${PREFIX}},{Key=Environment,Value=${ENVIRONMENT}},{Key=ProvisionedBy,Value=Terraform}]"
  fi
}

# Function to create KMS key
create_kms_key() {
  if aws kms list-aliases --query "Aliases[?AliasName=='${KMS_ALIAS}']" | grep -q "AliasName"; then
    echo "[$(date)] INFO: KMS alias ${KMS_ALIAS} already exists." | sudo tee -a "$LOGFILE"
    KMS_KEY_ID=$(aws kms describe-key --key-id "${KMS_ALIAS}" --query 'KeyMetadata.KeyId' --output text)
  else
    echo "[$(date)] INFO: Creating KMS key for backend encryption" | sudo tee -a "$LOGFILE"
    KMS_KEY_ID=$(aws kms create-key --tags TagKey=Project,TagValue=${PREFIX} TagKey=Environment,TagValue=${ENVIRONMENT} TagKey=ProvisionedBy,TagValue=Terraform --query 'KeyMetadata.KeyId' --output text)
    echo "[$(date)] INFO: KMS key created with ID: ${KMS_KEY_ID}" | sudo tee -a "$LOGFILE"
    echo "[$(date)] INFO: Creating KMS alias: ${KMS_ALIAS}" | sudo tee -a "$LOGFILE"
    aws kms create-alias --alias-name "${KMS_ALIAS}" --target-key-id "${KMS_KEY_ID}"
  fi
  echo "[$(date)] INFO: KMS key Alias: ${KMS_ALIAS}" | sudo tee -a "$LOGFILE"
}

# Function to create IAM role
create_iam_role() {
  local role_name=$1
  local assume_role_policy=$2
  if aws iam get-role --role-name "${role_name}" 2>/dev/null; then
    echo "[$(date)] INFO: IAM role ${role_name} already exists." | sudo tee -a "$LOGFILE"
  else
    echo "[$(date)] INFO: Creating IAM role: ${role_name}" | sudo tee -a "$LOGFILE"
    aws iam create-role --role-name "${role_name}" --assume-role-policy-document "${assume_role_policy}"
    echo "[$(date)] INFO: Tagging IAM role" | sudo tee -a "$LOGFILE"
    aws iam tag-role --role-name "${role_name}" --tags ${TAGS}
  fi
}

# Function to create IAM policy
create_iam_policy() {
  local policy_name=$1
  local policy_document=$2
  if aws iam list-policies --query "Policies[?PolicyName=='${policy_name}']" | grep -q "PolicyName"; then
    echo "[$(date)] INFO: IAM policy ${policy_name} already exists." | sudo tee -a "$LOGFILE"
    IAM_POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='${policy_name}'].Arn" --output text)
  else
    echo "[$(date)] INFO: Creating IAM policy: ${policy_name}" | sudo tee -a "$LOGFILE"
    IAM_POLICY_ARN=$(aws iam create-policy --policy-name "${policy_name}" --policy-document "${policy_document}" --query 'Policy.Arn' --output text)
  fi
  echo "[$(date)] INFO: Tagging IAM policy" | sudo tee -a "$LOGFILE"
  aws iam tag-policy --policy-arn "${IAM_POLICY_ARN}" --tags ${TAGS}
}

# Function to attach IAM policy to role
attach_iam_policy_to_role() {
  local role_name=$1
  local policy_arn=$2
  echo "[$(date)] INFO: Attaching IAM policy to role" | sudo tee -a "$LOGFILE"
  aws iam attach-role-policy --role-name "${role_name}" --policy-arn "${policy_arn}"
}

# Create S3 bucket
create_s3_bucket

# Create KMS key
create_kms_key

# Create IAM role for backend
BACKEND_ASSUME_ROLE_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:sts::678309485142:assumed-role/AWSReservedSSO_AdministratorAccess_203eb8c2d1ec0c2f/shawn@squarefoxtech.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'
create_iam_role "${IAM_ROLE_NAME}" "${BACKEND_ASSUME_ROLE_POLICY}"

# Create IAM policy for backend
BACKEND_POLICY_DOCUMENT='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::'"${BUCKET_NAME}"'",
        "arn:aws:s3:::'"${BUCKET_NAME}"'/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": [
        "arn:aws:kms:'"${REGION}"':'"${ACCOUNT_ID}"':key/'"${KMS_KEY_ID}"'"
      ]
    }
  ]
}'
create_iam_policy "${IAM_POLICY_NAME}" "${BACKEND_POLICY_DOCUMENT}"

# Attach IAM policy to backend role
attach_iam_policy_to_role "${IAM_ROLE_NAME}" "${IAM_POLICY_ARN}"

# Create IAM deployment role
DEPLOYMENT_ASSUME_ROLE_POLICY='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:sts::678309485142:assumed-role/AWSReservedSSO_AdministratorAccess_203eb8c2d1ec0c2f/shawn@squarefoxtech.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'
create_iam_role "${DEPLOYMENT_ROLE_NAME}" "${DEPLOYMENT_ASSUME_ROLE_POLICY}"

# Create IAM policy for deployment role
DEPLOYMENT_POLICY_DOCUMENT='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeAvailabilityZones",
        "ec2:RunInstances",
        "ec2:CreateSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "iam:CreateRole",
        "iam:AttachRolePolicy",
        "iam:CreatePolicy",
        "iam:PutRolePolicy",
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:DeleteFunction"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}'
create_iam_policy "${DEPLOYMENT_POLICY_NAME}" "${DEPLOYMENT_POLICY_DOCUMENT}"

# Attach IAM policy to deployment role
DEPLOYMENT_POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='${DEPLOYMENT_POLICY_NAME}'].Arn" --output text)
attach_iam_policy_to_role "${DEPLOYMENT_ROLE_NAME}" "${DEPLOYMENT_POLICY_ARN}"

# Output Terraform import statements
echo "[$(date)] INFO: To import the resources into Terraform state, use the following commands:" | sudo tee -a "$LOGFILE"
echo "terraform import aws_s3_bucket.tf_state_bucket ${BUCKET_NAME}" | sudo tee -a "$LOGFILE"
echo "terraform import aws_kms_key.tf_backend_key ${KMS_KEY_ID}" | sudo tee -a "$LOGFILE"
echo "terraform import aws_iam_role.tf_backend_role ${IAM_ROLE_NAME}" | sudo tee -a "$LOGFILE"
echo "terraform import aws_iam_policy.tf_backend_policy ${IAM_POLICY_ARN}" | sudo tee -a "$LOGFILE"

# Output Terraform backend configuration
echo "[$(date)] INFO: Add the following backend configuration to your Terraform configurations backend.tf:" | sudo tee -a "$LOGFILE"
echo "terraform {
  backend \"s3\" {
    bucket         = \"${BUCKET_NAME}\"
    key            = \"${ENVIRONMENT}/terraform.tfstate\"
    region         = \"${REGION}\"
    encrypt        = true
    kms_key_id     = \"${KMS_ALIAS}\"
    role_arn       = \"arn:aws:iam::${ACCOUNT_ID}:role/${IAM_ROLE_NAME}\"
  }
}" | sudo tee -a "$LOGFILE"

# Output the ARN of the deployment role
DEPLOYMENT_ROLE_ARN=$(aws iam get-role --role-name "${DEPLOYMENT_ROLE_NAME}" --query 'Role.Arn' --output text)
echo "[$(date)] INFO: Deployment role ARN: ${DEPLOYMENT_ROLE_ARN}" | sudo tee -a "$LOGFILE"
echo "output \"deployment_role_arn\" { value = \"${DEPLOYMENT_ROLE_ARN}\" }" >> output.tf