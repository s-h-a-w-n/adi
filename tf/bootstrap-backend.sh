#!/bin/sh -e

# Global Variables
REGION="us-east-1"
ACCOUNT_ID="678309485142"
ENVIRONMENT="production"
PREFIX="adi-sft"
LOGFILE="/var/log/${PREFIX}/bootstrap-backend.log"

if [ ! -d "$(dirname $LOGFILE)" ]; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating log directory: $(dirname $LOGFILE)" | sudo tee -a "$LOGFILE"
  sudo mkdir -p "$(dirname $LOGFILE)"
  sudo chmod 755 "$(dirname $LOGFILE)"
fi
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: log directory exists: $(dirname $LOGFILE)" | sudo tee -a "$LOGFILE"

if [ ! -f "$LOGFILE" ]; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating log file: $LOGFILE" | sudo tee -a "$LOGFILE"
  sudo touch "$LOGFILE"
  sudo chmod 644 "$LOGFILE"
fi
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: log file exists: $LOGFILE" | sudo tee -a "$LOGFILE"

BUCKET_NAME="${PREFIX}-${ENVIRONMENT}-tf-state"
IAM_ROLE_NAME="${PREFIX}-${ENVIRONMENT}-tf-backend-role"
IAM_POLICY_NAME="${PREFIX}-${ENVIRONMENT}-tf-backend-policy"
KMS_ALIAS="alias/${PREFIX}-${ENVIRONMENT}-tf-backend"
IAM_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${IAM_POLICY_NAME}"
TAGS="Key=Project,Value=${PREFIX} Key=Environment,Value=${ENVIRONMENT} Key=ProvisionedBy,Value=Terraform"

# Create S3 bucket
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: S3 bucket ${BUCKET_NAME} already exists." | sudo tee -a "$LOGFILE"
else
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating S3 bucket for Terraform state: ${BUCKET_NAME}" | sudo tee -a "$LOGFILE"
  aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" --create-bucket-configuration LocationConstraint="${REGION}"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Enabling versioning on S3 bucket" | sudo tee -a "$LOGFILE"
  aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" --versioning-configuration Status=Enabled
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Tagging S3 bucket" | sudo tee -a "$LOGFILE"
  aws s3api put-bucket-tagging --bucket "${BUCKET_NAME}" --tagging "TagSet=[{Key=Project,Value=${PREFIX}},{Key=Environment,Value=${ENVIRONMENT}},{Key=ProvisionedBy,Value=Terraform}]"
fi

# Create KMS key
if aws kms list-aliases --query "Aliases[?AliasName=='${KMS_ALIAS}']" | grep -q "AliasName"; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: KMS alias ${KMS_ALIAS} already exists." | sudo tee -a "$LOGFILE"
  KMS_KEY_ID=$(aws kms describe-key --key-id "${KMS_ALIAS}" --query 'KeyMetadata.KeyId' --output text)
else
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating KMS key for backend encryption" | sudo tee -a "$LOGFILE"
  KMS_KEY_ID=$(aws kms create-key --tags TagKey=Project,TagValue=${PREFIX} TagKey=Environment,TagValue=${ENVIRONMENT} TagKey=ProvisionedBy,TagValue=Terraform --query 'KeyMetadata.KeyId' --output text)
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: KMS key created with ID: ${KMS_KEY_ID}" | sudo tee -a "$LOGFILE"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating KMS alias: ${KMS_ALIAS}" | sudo tee -a "$LOGFILE"
  aws kms create-alias --alias-name "${KMS_ALIAS}" --target-key-id "${KMS_KEY_ID}"
fi
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: KMS key Alias: ${KMS_ALIAS}" | sudo tee -a "$LOGFILE"

# Create IAM role
if aws iam get-role --role-name "${IAM_ROLE_NAME}" 2>/dev/null; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: IAM role ${IAM_ROLE_NAME} already exists." | sudo tee -a "$LOGFILE"
else
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating IAM role: ${IAM_ROLE_NAME}" | sudo tee -a "$LOGFILE"
  aws iam create-role --role-name "${IAM_ROLE_NAME}" --assume-role-policy-document '{
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
fi
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Tagging IAM role" | sudo tee -a "$LOGFILE"
aws iam tag-role --role-name "${IAM_ROLE_NAME}" --tags ${TAGS}

# Create IAM policy
if aws iam list-policies --query "Policies[?PolicyName=='${IAM_POLICY_NAME}']" | grep -q "PolicyName"; then
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: IAM policy ${IAM_POLICY_NAME} already exists." | sudo tee -a "$LOGFILE"
  # Capture the policy ARN
  IAM_POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='${IAM_POLICY_NAME}'].Arn" --output text)
else
  echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Creating IAM policy: ${IAM_POLICY_NAME}" | sudo tee -a "$LOGFILE"
  IAM_POLICY_DOCUMENT='{
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
  # Create the policy and capture its ARN
  IAM_POLICY_ARN=$(aws iam create-policy --policy-name "${IAM_POLICY_NAME}" --policy-document "${IAM_POLICY_DOCUMENT}" --query 'Policy.Arn' --output text)
fi

echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Tagging IAM policy" | sudo tee -a "$LOGFILE"
aws iam tag-policy --policy-arn "${IAM_POLICY_ARN}" --tags ${TAGS}

# Attach policy to IAM role
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Attaching IAM policy to role" | sudo tee -a "$LOGFILE"
aws iam attach-role-policy --role-name "${IAM_ROLE_NAME}" --policy-arn "${IAM_POLICY_ARN}"

# Output Terraform import statements
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: To import the resources into Terraform state, use the following commands:" | sudo tee -a "$LOGFILE"
echo "terraform import aws_s3_bucket.tf_state_bucket ${BUCKET_NAME}" | sudo tee -a "$LOGFILE"
echo "terraform import aws_kms_key.tf_backend_key ${KMS_KEY_ID}" | sudo tee -a "$LOGFILE"
echo "terraform import aws_iam_role.tf_backend_role ${IAM_ROLE_NAME}" | sudo tee -a "$LOGFILE"
echo "terraform import aws_iam_policy.tf_backend_policy ${IAM_POLICY_ARN}" | sudo tee -a "$LOGFILE"

# Output Terraform backend configuration
echo "[$(date '+%Y-%m-%dT%H:%M:%S%z')] INFO: Add the following backend configuration to your Terraform configurations backend.tf:" | sudo tee -a "$LOGFILE"
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