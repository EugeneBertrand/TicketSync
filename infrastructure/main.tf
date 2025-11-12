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

# Enables the static website hosting feature
resource "aws_s3_bucket_website_configuration" "ticket_sync_website" {
  bucket = aws_s3_bucket.ticket_sync_bucket.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    suffix = "index.html" # For React Router
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
  name = "ticketsync-admin-users"

  # Password policy (stricter for admins)
  password_policy {
    minimum_length    = 10
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

  # MFA configuration (recommended for admins)
  mfa_configuration = "OPTIONAL"

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
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

# This is the IAM Policy (the "rules")
resource "aws_iam_policy" "developer_s3_access" {
  name        = "TicketSync-S3-Upload-Access"
  description = "Allows developers to manage the TicketSync S3 bucket"

  # This is the JSON we wrote, now stored as code.
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Sid"    = "AllowGroupToManageBucket",
        "Effect" = "Allow",
        "Action" = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" = [
          aws_s3_bucket.ticket_sync_bucket.arn,       # Connects to the S3 bucket
          "${aws_s3_bucket.ticket_sync_bucket.arn}/*" # Connects to the objects *inside* the bucket
        ]
      },
      {
        "Sid"       = "AllowGroupToListAllBuckets",
        "Effect"    = "Allow",
        "Action"    = "s3:ListAllMyBuckets",
        "Resource"  = "*"
      }
    ]
  })
}

# This is the IAM Group (the "team")
resource "aws_iam_group" "developer_group" {
  name = "TicketSync-Developers"
}

# This is the "glue" that connects the policy to the group
resource "aws_iam_group_policy_attachment" "attach_s3_access" {
  group      = aws_iam_group.developer_group.name
  policy_arn = aws_iam_policy.developer_s3_access.arn
}

# This creates your teammate's user account
# You can change the name or add more blocks like this
resource "aws_iam_user" "teammate_user" {
  name = "teammate-github-username" # CHANGE THIS
}

# And this "glues" the user to the group
resource "aws_iam_user_group_membership" "add_teammate_to_group" {
  user   = aws_iam_user.teammate_user.name
  groups = [aws_iam_group.developer_group.name]
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
