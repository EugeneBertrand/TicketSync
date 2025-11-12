#!/bin/bash

# Script to set up environment variables from Terraform outputs
# Usage: ./scripts/setup-env.sh

echo "Setting up environment variables from Terraform outputs..."

cd infrastructure

# Get Terraform outputs
CLIENT_POOL_ID=$(terraform output -raw client_user_pool_id)
CLIENT_CLIENT_ID=$(terraform output -raw client_user_pool_client_id)
ADMIN_POOL_ID=$(terraform output -raw admin_user_pool_id)
ADMIN_CLIENT_ID=$(terraform output -raw admin_user_pool_client_id)
AWS_REGION=$(terraform output -raw aws_region)

cd ..

# Create .env file
cat > .env << EOF
# AWS Configuration
VITE_AWS_REGION=${AWS_REGION}

# Cognito Client User Pool Configuration
VITE_CLIENT_USER_POOL_ID=${CLIENT_POOL_ID}
VITE_CLIENT_USER_POOL_CLIENT_ID=${CLIENT_CLIENT_ID}

# Cognito Admin User Pool Configuration
VITE_ADMIN_USER_POOL_ID=${ADMIN_POOL_ID}
VITE_ADMIN_USER_POOL_CLIENT_ID=${ADMIN_CLIENT_ID}
EOF

echo "Environment variables have been set in .env file"
echo "You can now run 'npm install' and 'npm run dev' to start the development server"

