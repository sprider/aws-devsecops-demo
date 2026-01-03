#!/bin/bash
#
# Terraform Backend Setup Script
# This script creates the S3 bucket and DynamoDB table for secure Terraform state storage
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured. Run 'aws configure' first."
    exit 1
fi

# Configuration
DEFAULT_BUCKET="terraform-state-$(aws sts get-caller-identity --query Account --output text)"
DEFAULT_TABLE="terraform-state-lock"
DEFAULT_REGION="us-east-1"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        Terraform Backend Setup                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Get bucket name
read -p "Enter S3 bucket name [${DEFAULT_BUCKET}]: " BUCKET_NAME
BUCKET_NAME=${BUCKET_NAME:-$DEFAULT_BUCKET}

# Get DynamoDB table name
read -p "Enter DynamoDB table name [${DEFAULT_TABLE}]: " TABLE_NAME
TABLE_NAME=${TABLE_NAME:-$DEFAULT_TABLE}

# Get region
read -p "Enter AWS region [${DEFAULT_REGION}]: " REGION
REGION=${REGION:-$DEFAULT_REGION}

echo ""
print_info "Creating backend with the following configuration:"
echo "  Bucket: ${BUCKET_NAME}"
echo "  Table: ${TABLE_NAME}"
echo "  Region: ${REGION}"
echo ""

read -p "Proceed? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_info "Aborted by user"
    exit 0
fi

echo ""

# Create S3 bucket
print_info "Creating S3 bucket: ${BUCKET_NAME}"
if aws s3 mb "s3://${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
    print_success "S3 bucket created"
else
    if aws s3 ls "s3://${BUCKET_NAME}" &> /dev/null; then
        print_warning "S3 bucket already exists"
    else
        print_error "Failed to create S3 bucket"
        exit 1
    fi
fi

# Enable versioning
print_info "Enabling versioning on S3 bucket"
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled \
    --region "${REGION}"
print_success "Versioning enabled"

# Enable encryption
print_info "Enabling server-side encryption (AES-256)"
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --region "${REGION}"
print_success "Encryption enabled"

# Block public access
print_info "Blocking public access"
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "${REGION}"
print_success "Public access blocked"

# Enable bucket logging (optional but recommended)
print_info "Configuring bucket lifecycle policy"
aws s3api put-bucket-lifecycle-configuration \
    --bucket "${BUCKET_NAME}" \
    --lifecycle-configuration '{
        "Rules": [{
            "Id": "DeleteOldVersions",
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            }
        }]
    }' \
    --region "${REGION}"
print_success "Lifecycle policy configured"

# Create DynamoDB table
print_info "Creating DynamoDB table: ${TABLE_NAME}"
if aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    &> /dev/null; then
    print_success "DynamoDB table created"

    # Wait for table to be active
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists --table-name "${TABLE_NAME}" --region "${REGION}"
    print_success "DynamoDB table is active"
else
    if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" &> /dev/null; then
        print_warning "DynamoDB table already exists"
    else
        print_error "Failed to create DynamoDB table"
        exit 1
    fi
fi

# Enable point-in-time recovery for DynamoDB
print_info "Enabling point-in-time recovery for DynamoDB"
aws dynamodb update-continuous-backups \
    --table-name "${TABLE_NAME}" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "${REGION}" \
    &> /dev/null || print_warning "Could not enable point-in-time recovery"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        Backend Setup Complete!                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

print_success "Backend resources created successfully"
echo ""
print_info "Next steps:"
echo ""
echo "1. Update backend.tf with your configuration:"
echo "   bucket         = \"${BUCKET_NAME}\""
echo "   region         = \"${REGION}\""
echo "   dynamodb_table = \"${TABLE_NAME}\""
echo ""
echo "2. Initialize Terraform with the new backend:"
echo "   cd platform-terraform"
echo "   terraform init -migrate-state"
echo ""
echo "3. Verify state is stored in S3:"
echo "   aws s3 ls s3://${BUCKET_NAME}/devsecops-demo/"
echo ""

print_warning "IMPORTANT: Keep backend.tf in version control, but NEVER commit terraform.tfstate files!"
echo ""
