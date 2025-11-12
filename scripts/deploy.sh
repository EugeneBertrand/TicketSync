#!/bin/bash

# Script to build and deploy the React app to S3
# Usage: ./scripts/deploy.sh

set -e

echo "Building React application..."

# Build the app
npm run build

echo "Build complete!"

# Get S3 bucket name from Terraform
cd infrastructure
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
cd ..

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not get S3 bucket name from Terraform"
    echo "Please make sure Terraform has been applied and the bucket exists"
    exit 1
fi

echo "Deploying to S3 bucket: $BUCKET_NAME"

# Sync build files to S3
aws s3 sync dist/ s3://$BUCKET_NAME --delete

echo "Deployment complete!"
echo "Your application is available at the S3 website endpoint"
echo "Get the endpoint with: cd infrastructure && terraform output s3_bucket_website_endpoint"

