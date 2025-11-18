###
# TicketSync Infrastructure
# This one file defines both the S3 bucket and the developer permissions.
###

# 1. Configure the AWS Provider
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

#---------------------------------------
# SECTION 1: S3 BUCKET FOR REACT APP
#---------------------------------------

# Defines the S3 bucket itself
resource "aws_s3_bucket" "ticket_sync_bucket" {
  # ---
  # IMPORTANT: CHANGE THIS BUCKET NAME!
  # It must be globally unique.
  # ---
  bucket = "ticketsync-app-my-unique-name-12345"
}

# Configures public access settings
resource "aws_s3_bucket_public_access_block" "ticket_sync_public_access" {
  bucket = aws_s3_bucket.ticket_sync_bucket.id

  block_public_acls       = true
  block_public_policy     = false # We need this OFF to add a policy
  ignore_public_acls      = true
  restrict_public_buckets = false # We need this OFF
}

# Applies the PUBLIC read-only policy
resource "aws_s3_bucket_policy" "ticket_sync_policy" {
  bucket = aws_s3_bucket.ticket_sync_bucket.id
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [{
      "Sid"       = "PublicReadGetObject",
      "Effect"    = "Allow",
      "Principal" = "*",
      "Action"    = "s3:GetObject",
      "Resource"  = "${aws_s3_bucket.ticket_sync_bucket.arn}/*"
    }]
  })
}

# Configures the website settings for the S3 bucket
resource "aws_s3_bucket_website_configuration" "ticket_sync_website" {
  bucket = aws_s3_bucket.ticket_sync_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

#---------------------------------------
# SECTION 2: AWS COGNITO FOR AUTHENTICATION
#---------------------------------------

# Cognito User Pool for Clients
resource "aws_cognito_user_pool" "client_user_pool" {
  name = "ticketsync-client-users"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Auto-verify email
  auto_verified_attributes = ["email"]

  # MFA configuration (optional - can be enabled later)
  mfa_configuration = "OFF"

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  lifecycle {
    ignore_changes = [schema]
  }
}

# Cognito User Pool Client for Clients
resource "aws_cognito_user_pool_client" "client_user_pool_client" {
  name         = "ticketsync-client-app-client"
  user_pool_id = aws_cognito_user_pool.client_user_pool.id

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Token validity (in hours)
  access_token_validity  = 24
  id_token_validity      = 24
  refresh_token_validity = 720

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # OAuth settings (if needed for future integrations)
  supported_identity_providers = ["COGNITO"]
}

# Cognito User Pool for Admins
resource "aws_cognito_user_pool" "admin_user_pool" {
  name = "ticket-sync-admin-pool"
  
  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # MFA configuration - disabling MFA for now to fix the error
  mfa_configuration = "OFF"

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Username configuration
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]

  # Verification message template
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject = "Your Verification Code"
    email_message = "Your verification code is {####}"
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = true

    invite_message_template {
      email_subject = "Your temporary password for TicketSync Admin"
      email_message = "Your username is {username} and temporary password is {####}."
      sms_message   = "Your username is {username} and temporary password is {####}."
    }
  }
}

# Cognito User Pool Client for Admins
resource "aws_cognito_user_pool_client" "admin_user_pool_client" {
  name         = "ticketsync-admin-app-client"
  user_pool_id = aws_cognito_user_pool.admin_user_pool.id

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Token validity (shorter for admins for security)
  access_token_validity  = 8
  id_token_validity      = 8
  refresh_token_validity = 720

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # OAuth settings (if needed for future integrations)
  supported_identity_providers = ["COGNITO"]
}

#---------------------------------------
# SECTION 3: IAM FOR DEVELOPER ACCESS
#---------------------------------------

# Data source to import existing IAM policy
data "aws_iam_policy" "developer_s3_access" {
  name = "TicketSync-S3-Upload-Access"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to import existing IAM group
data "aws_iam_group" "developer_group" {
  group_name = "TicketSync-Developers"
}

# IAM Policy for Cognito User Pool access
resource "aws_iam_policy" "cognito_access" {
  name        = "TicketSync-Cognito-Access"
  description = "IAM policy for managing Cognito User Pools"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:ListUsers",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminUpdateUserAttributes",
          "cognito-idp:AdminRespondToAuthChallenge",
          "cognito-idp:AdminSetUserPassword"
        ]
        Resource = [
          "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${aws_cognito_user_pool.client_user_pool.id}",
          "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${aws_cognito_user_pool.admin_user_pool.id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:ListUserPools",
          "cognito-idp:DescribeUserPoolClient"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach Cognito policy to developer group
resource "aws_iam_group_policy_attachment" "cognito_access" {
  group      = data.aws_iam_group.developer_group.group_name
  policy_arn = aws_iam_policy.cognito_access.arn
}

# Create IAM users for team members with console access
resource "aws_iam_user" "team_members" {
  for_each = {
    "Dhruv" = "Dhruv111"
    "Yuv" = "Yuvmagan22"
    "Clarissa" = "Clarissa22"
  }
  
  name = each.key
  
  # Enable console access
  force_destroy = true  # Allows user deletion via Terraform
  
  tags = {
    ManagedBy = "Terraform"
    Purpose  = "TicketSync Console Access"
  }
}

# Add team members to the developer group
resource "aws_iam_user_group_membership" "add_team_to_group" {
  for_each = aws_iam_user.team_members
  
  user   = each.value.name
  groups = [data.aws_iam_group.developer_group.group_name]
}

#---------------------------------------
# SECTION 4: OUTPUTS
#---------------------------------------

# S3 Bucket outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.ticket_sync_bucket.id
}

output "s3_bucket_website_endpoint" {
  description = "Website endpoint for the S3 bucket"
  value       = aws_s3_bucket_website_configuration.ticket_sync_website.website_endpoint
}

# Cognito outputs for Client
output "client_user_pool_id" {
  description = "Client User Pool ID"
  value       = aws_cognito_user_pool.client_user_pool.id
}

output "client_user_pool_client_id" {
  description = "Client User Pool Client ID"
  value       = aws_cognito_user_pool_client.client_user_pool_client.id
  sensitive   = false
}

# Cognito outputs for Admin
output "admin_user_pool_id" {
  description = "Admin User Pool ID"
  value       = aws_cognito_user_pool.admin_user_pool.id
}

output "admin_user_pool_client_id" {
  description = "Admin User Pool Client ID"
  value       = aws_cognito_user_pool_client.admin_user_pool_client.id
  sensitive   = false
}

# AWS Region
output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}