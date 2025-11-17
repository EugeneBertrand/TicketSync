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
  name = "Yuv28" 
}

# And this "glues" the user to the group
resource "aws_iam_user_group_membership" "add_teammate_to_group" {
  user   = aws_iam_user.teammate_user.name
  groups = [aws_iam_group.developer_group.name]
}
# this code creates the DynamoDB table called "tickets" and sets up its key "ticket_id"
resource "aws_dynamodb_table" "tickets" {
  name           = "tickets"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ticket_id"
# these add "columns" to the table, both of type string, for the ticket_id and sentiment (need to add more for date and status)
  attribute {
    name = "ticket_id"
    type = "S"
  }
  attribute {
    name = "sentiment"
    type = "S"
  }
}
# sets up the IAM role for the lamdba functions called "lambda_role"
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}
# IAM policy that gives "lambda_role" basic lambda executions
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# IAM policy that gives "lambda_role" full access to DynamoDB
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
# sets up the lambda function called "ticket_processer"
resource "aws_lambda_function" "ticket_processor" {
  function_name = "ticketProcessor"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn

  filename = "lambda_function.zip"  # Your packaged Lambda code
}
# sets up the REST API "ticket_api"
resource "aws_api_gateway_rest_api" "ticket_api" {
  name = "ticketAPI"
}
# sets up a path called "tickets" that will connect incoming dat to API Gateway
resource "aws_api_gateway_resource" "tickets" {
  rest_api_id = aws_api_gateway_rest_api.ticket_api.id
  parent_id   = aws_api_gateway_rest_api.ticket_api.root_resource_id
  path_part   = "tickets"
}
# allows for POST requests to be made on the tickets path which will send ticket data directly to the API Gateway and to the lambda function
resource "aws_api_gateway_method" "post_tickets" {
  rest_api_id   = aws_api_gateway_rest_api.ticket_api.id
  resource_id   = aws_api_gateway_resource.tickets.id
  http_method   = "POST"
  authorization = "NONE"
}
# connects the POST method to the ticket_processor lambda function
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.ticket_api.id
  resource_id = aws_api_gateway_resource.tickets.id
  http_method = aws_api_gateway_method.post_tickets.http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.ticket_processor.invoke_arn
}
# sets up permissions for lambda to get data through API Gateway
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ticket_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ticket_api.execution_arn}/*/*"
}