###
# TicketSync Infrastructure
# This one file defines both the S3 bucket and the developer permissions.
###

# 1. Configure the AWS Provider
provider "aws" {
  region = "us-east-1" # You can change this
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
# SECTION 2: IAM FOR DEVELOPER ACCESS
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
