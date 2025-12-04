# TicketSync Deployment Guide

This guide walks you through deploying the TicketSync application with the React login portal and AWS infrastructure.

## Prerequisites

- AWS Account with appropriate permissions
- Terraform installed (v1.0+)
- AWS CLI configured
- Node.js and npm installed
- Git (optional)

## Step 1: Deploy Infrastructure

1. Navigate to the infrastructure directory:
```bash
cd infrastructure
```

2. Initialize Terraform:
```bash
terraform init
```

3. Update the S3 bucket name in `main.tf` (line 21):
   - The bucket name must be globally unique
   - Change `ticketsync-app-my-unique-name-12345` to your unique name

4. (Optional) Update the AWS region:
   - Edit the `aws_region` variable in `main.tf` (default is `us-east-1`)

5. Review the Terraform plan:
```bash
terraform plan
```

6. Apply the infrastructure:
```bash
terraform apply
```

7. Save the outputs - you'll need these for the React app:
   - `client_user_pool_id`
   - `client_user_pool_client_id`
   - `admin_user_pool_id`
   - `admin_user_pool_client_id`
   - `aws_region`
   - `s3_bucket_name`
   - `s3_bucket_website_endpoint`

## Step 2: Configure React Application

1. Navigate back to the project root:
```bash
cd ..
```

2. Run the setup script to automatically create `.env` from Terraform outputs:
```bash
./scripts/setup-env.sh
```

   Or manually create a `.env` file:
```bash
cp .env.example .env
```

   Then update `.env` with the values from Terraform outputs:
```env
VITE_AWS_REGION=us-east-1
VITE_CLIENT_USER_POOL_ID=us-east-1_xxxxxxxxx
VITE_CLIENT_USER_POOL_CLIENT_ID=xxxxxxxxxxxxxxxxxx
VITE_ADMIN_USER_POOL_ID=us-east-1_yyyyyyyyy
VITE_ADMIN_USER_POOL_CLIENT_ID=yyyyyyyyyyyyyyyyyy
```

## Step 3: Install Dependencies and Test Locally

1. Install npm dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm run dev
```

3. Open your browser to `http://localhost:5173`

4. Test the login portal:
   - Select "Client Login" or "Admin Login"
   - Create a new account (sign up)
   - Check your email for the confirmation code
   - Confirm your account
   - Sign in with your credentials

## Step 4: Build and Deploy to S3

1. Build the production version:
```bash
npm run build
```

2. Deploy to S3 using the deployment script:
```bash
./scripts/deploy.sh
```

   Or manually:
```bash
# Get the bucket name from Terraform
cd infrastructure
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
cd ..

# Deploy to S3
aws s3 sync dist/ s3://$BUCKET_NAME --delete
```

3. Get your website URL:
```bash
cd infrastructure
terraform output s3_bucket_website_endpoint
```

4. Your application is now live! Access it at:
   - `http://<bucket-name>.s3-website-<region>.amazonaws.com`

## Step 5: Create Test Users (Optional)

You can create test users in AWS Cognito Console:

1. Go to AWS Cognito Console
2. Select the appropriate User Pool (Client or Admin)
3. Click "Create user"
4. Enter email and temporary password
5. User will need to change password on first login

Or use AWS CLI:
```bash
# Create a client user
aws cognito-idp admin-create-user \
  --user-pool-id <CLIENT_USER_POOL_ID> \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Create an admin user
aws cognito-idp admin-create-user \
  --user-pool-id <ADMIN_USER_POOL_ID> \
  --username admin@example.com \
  --user-attributes Name=email,Value=admin@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS
```

## Troubleshooting

### Authentication Issues

1. **"Cognito configuration is missing" error:**
   - Verify that `.env` file exists and has all required variables
   - Check that Terraform outputs are correct
   - Restart the development server after updating `.env`

2. **"User does not exist" error:**
   - Make sure you're using the correct user pool (client vs admin)
   - Verify the user exists in the correct Cognito User Pool
   - Check that email verification is complete

3. **Email confirmation not received:**
   - Check spam folder
   - Verify email address in Cognito User Pool
   - Check Cognito email configuration (uses SES in production)

### Deployment Issues

1. **S3 sync fails:**
   - Verify AWS credentials are configured
   - Check that you have permissions to write to the S3 bucket
   - Ensure the bucket exists (run `terraform apply`)

2. **Website not accessible:**
   - Verify S3 bucket has public read access
   - Check bucket policy allows public GetObject
   - Verify website hosting is enabled
   - Check bucket website endpoint URL

### Terraform Issues

1. **"Bucket name already exists":**
   - Change the bucket name in `main.tf` to something unique
   - Bucket names must be globally unique across all AWS accounts

2. **"Access Denied" errors:**
   - Verify AWS credentials have necessary permissions
   - Check IAM policies for Terraform execution
   - Ensure you have permissions to create Cognito User Pools

## Security Notes

1. **Never commit `.env` file to git** - it contains sensitive configuration
2. **Use strong passwords** - especially for admin accounts
3. **Enable MFA** for admin users in production
4. **Use HTTPS** - configure CloudFront and SSL certificate for production
5. **Review IAM policies** - ensure least privilege access

## Next Steps

- Set up CloudFront for CDN and HTTPS
- Configure custom domain
- Set up CI/CD pipeline
- Enable MFA for admin users
- Configure SES for email (if not using Cognito default)
- Set up monitoring and logging
- Implement ticket management features

## Cleanup

To destroy all resources:

```bash
cd infrastructure
terraform destroy
```

**Warning:** This will delete all resources including S3 bucket, Cognito User Pools, and all user data.

