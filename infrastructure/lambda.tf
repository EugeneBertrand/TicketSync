###############################################
# Terraform: Lambda + API Gateway + IAM Setup
# Project: TicketSync
###############################################
# -----------------------------
# 2️⃣ IAM Roles & Policies
# -----------------------------

# ----- Email Lambda Role -----
resource "aws_iam_role" "lambda_email_role" {
  name = "ticketsync-email-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = { Name = "TicketSync Email Lambda Role", Environment = var.environment }
}

# Attach basic execution role (CloudWatch logs)
resource "aws_iam_role_policy_attachment" "lambda_logs_email" {
  role       = aws_iam_role.lambda_email_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SES policy for sending emails
resource "aws_iam_policy" "lambda_ses_policy" {
  name        = "ticketsync-lambda-ses-policy"
  description = "Allow Lambda to send emails via SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail","ses:SendRawEmail"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ses_attach" {
  role       = aws_iam_role.lambda_email_role.name
  policy_arn = aws_iam_policy.lambda_ses_policy.arn
}

# DynamoDB access for Email Lambda (optional)
resource "aws_iam_policy" "lambda_dynamodb_policy_email" {
  name        = "ticketsync-lambda-dynamodb-policy-email"
  description = "Email Lambda DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:Query","dynamodb:Scan"]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.tickets.arn,
          aws_dynamodb_table.tickets_test.arn,
          "${aws_dynamodb_table.users.arn}/index/*",
          "${aws_dynamodb_table.tickets.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach_email" {
  role       = aws_iam_role.lambda_email_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy_email.arn
}

# ----- Ticket Lambda Role -----
resource "aws_iam_role" "lambda_ticket_role" {
  name = "ticketsync-ticket-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })

  tags = { Name = "TicketSync Ticket Lambda Role", Environment = var.environment }
}

resource "aws_iam_role_policy_attachment" "lambda_logs_ticket" {
  role       = aws_iam_role.lambda_ticket_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Ticket Lambda policy (DynamoDB + Comprehend)
resource "aws_iam_policy" "lambda_ticket_policy" {
  name        = "ticketsync-lambda-ticket-policy"
  description = "Allow Lambda to access DynamoDB and Comprehend"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:Query","dynamodb:Scan"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["comprehend:DetectSentiment"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ticket_lambda_policy_attach" {
  role       = aws_iam_role.lambda_ticket_role.name
  policy_arn = aws_iam_policy.lambda_ticket_policy.arn
}

# -----------------------------
# 3️⃣ Package Lambda Code
# -----------------------------

# Email Lambda zip
data "archive_file" "email_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/email_handler.py"
  output_path = "${path.module}/../lambda/email_handler.zip"
}

# Ticket Lambda zip
data "archive_file" "ticket_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.zip"
}

# -----------------------------
# 4️⃣ Lambda Functions
# -----------------------------

# Email Lambda
resource "aws_lambda_function" "email_handler" {
  filename         = data.archive_file.email_lambda_zip.output_path
  function_name    = "ticketsync-email-handler"
  role             = aws_iam_role.lambda_email_role.arn
  handler          = "email_handler.lambda_handler"
  source_code_hash = data.archive_file.email_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment { variables = { SENDER_EMAIL = "csaputra@ucsd.edu" } }

  tags = { Name = "TicketSync Email Handler", Environment = var.environment }
}

# Ticket Lambda
resource "aws_lambda_function" "ticket_handler" {
  filename         = data.archive_file.ticket_lambda_zip.output_path
  function_name    = "ticketsync-ticket-handler"
  role             = aws_iam_role.lambda_ticket_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.ticket_lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment { variables = { DYNAMODB_TABLE = aws_dynamodb_table.tickets_test.name } }

  tags = { Name = "TicketSync Ticket Handler", Environment = var.environment }
}

# -----------------------------
# 5️⃣ API Gateway for Email Lambda
# -----------------------------
resource "aws_api_gateway_rest_api" "email_api" {
  name        = "ticketsync-email-api"
  description = "API Gateway for TicketSync Email Service"
  endpoint_configuration { types = ["REGIONAL"] }
  tags = { Name = "TicketSync Email API", Environment = var.environment }
}

resource "aws_api_gateway_resource" "email_resource" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  parent_id   = aws_api_gateway_rest_api.email_api.root_resource_id
  path_part   = "send-email"
}

# POST and OPTIONS for Email Lambda
resource "aws_api_gateway_method" "email_post" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "email_options" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integration for Email Lambda POST
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.email_api.id
  resource_id             = aws_api_gateway_resource.email_resource.id
  http_method             = aws_api_gateway_method.email_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.email_handler.invoke_arn
}

# CORS integration
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id       = aws_api_gateway_rest_api.email_api.id
  resource_id       = aws_api_gateway_resource.email_resource.id
  http_method       = aws_api_gateway_method.email_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email_resource.id
  http_method   = aws_api_gateway_method.email_options.http_method
  status_code   = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email_resource.id
  http_method   = aws_api_gateway_method.email_options.http_method
  status_code   = aws_api_gateway_method_response.options_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.email_api.execution_arn}/*/*"
}

# Deployment and stage
resource "aws_api_gateway_deployment" "email_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  depends_on  = [aws_api_gateway_integration.lambda_integration, aws_api_gateway_integration.options_integration]
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "email_api_stage" {
  deployment_id = aws_api_gateway_deployment.email_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  stage_name    = var.environment
  tags          = { Name = "TicketSync Email API Stage", Environment = var.environment }
}

# -----------------------------
# 6️⃣ API Gateway for Ticket Lambda
# -----------------------------
# This will be the same structure as above, just for ticket_handler and /tickets
resource "aws_api_gateway_rest_api" "ticket_api" {
  name        = "ticketsync-ticket-api"
  description = "API Gateway for TicketSync Ticket Service"
  endpoint_configuration { types = ["REGIONAL"] }

  tags = { Name = "TicketSync Ticket API", Environment = var.environment }
}

# Resource path: /tickets
resource "aws_api_gateway_resource" "ticket_resource" {
  rest_api_id = aws_api_gateway_rest_api.ticket_api.id
  parent_id   = aws_api_gateway_rest_api.ticket_api.root_resource_id
  path_part   = "tickets"
}

# POST method for creating tickets
resource "aws_api_gateway_method" "ticket_post" {
  rest_api_id   = aws_api_gateway_rest_api.ticket_api.id
  resource_id   = aws_api_gateway_resource.ticket_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# OPTIONS method for CORS preflight
resource "aws_api_gateway_method" "ticket_options" {
  rest_api_id   = aws_api_gateway_rest_api.ticket_api.id
  resource_id   = aws_api_gateway_resource.ticket_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integration: POST → Lambda (AWS_PROXY)
resource "aws_api_gateway_integration" "ticket_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ticket_api.id
  resource_id             = aws_api_gateway_resource.ticket_resource.id
  http_method             = aws_api_gateway_method.ticket_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ticket_handler.invoke_arn
}

# Integration: OPTIONS → MOCK (CORS preflight)
resource "aws_api_gateway_integration" "ticket_options_integration" {
  rest_api_id       = aws_api_gateway_rest_api.ticket_api.id
  resource_id       = aws_api_gateway_resource.ticket_resource.id
  http_method       = aws_api_gateway_method.ticket_options.http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

# Method response for OPTIONS
resource "aws_api_gateway_method_response" "ticket_options_response" {
  rest_api_id   = aws_api_gateway_rest_api.ticket_api.id
  resource_id   = aws_api_gateway_resource.ticket_resource.id
  http_method   = aws_api_gateway_method.ticket_options.http_method
  status_code   = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "ticket_options_integration_response" {
  rest_api_id   = aws_api_gateway_rest_api.ticket_api.id
  resource_id   = aws_api_gateway_resource.ticket_resource.id
  http_method   = aws_api_gateway_method.ticket_options.http_method
  status_code   = aws_api_gateway_method_response.ticket_options_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "ticket_api_permission" {
  statement_id  = "AllowTicketAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ticket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ticket_api.execution_arn}/*/*"
}

# Deployment and Stage
resource "aws_api_gateway_deployment" "ticket_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.ticket_api.id
  depends_on  = [
    aws_api_gateway_integration.ticket_lambda_integration,
    aws_api_gateway_integration.ticket_options_integration
  ]
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "ticket_api_stage" {
  deployment_id = aws_api_gateway_deployment.ticket_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.ticket_api.id
  stage_name    = var.environment
  tags          = { Name = "TicketSync Ticket API Stage", Environment = var.environment }
}


# -----------------------------
# 7️⃣ EventBridge Scheduler for Email Alerts
# -----------------------------

# EventBridge rule to trigger email Lambda every 7 days
resource "aws_cloudwatch_event_rule" "email_scheduler" {
  name                = "ticketsync-email-scheduler"
  description         = "Triggers email alert Lambda every 7 days"
  schedule_expression = "rate(7 days)"

  tags = {
    Name        = "TicketSync Email Scheduler"
    Environment = var.environment
  }
}

# Target: Email Lambda function
resource "aws_cloudwatch_event_target" "email_lambda_target" {
  rule      = aws_cloudwatch_event_rule.email_scheduler.name
  target_id = "EmailLambdaTarget"
  arn       = aws_lambda_function.email_handler.arn
}

# Permission for EventBridge to invoke the Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.email_scheduler.arn
}

# -----------------------------
# 8️⃣ Outputs
# -----------------------------
output "email_lambda_name" {
  value = aws_lambda_function.email_handler.function_name
}

output "ticket_lambda_name" {
  value = aws_lambda_function.ticket_handler.function_name
}

output "ticket_table_name" {
  value = aws_dynamodb_table.tickets.name
}

output "email_api_url" {
  value = "${aws_api_gateway_stage.email_api_stage.invoke_url}/send-email"
}

output "ticket_api_url" {
  value = "${aws_api_gateway_stage.ticket_api_stage.invoke_url}/tickets"
}

output "email_scheduler_status" {
  description = "Email scheduler configuration"
  value = {
    name     = aws_cloudwatch_event_rule.email_scheduler.name
    schedule = aws_cloudwatch_event_rule.email_scheduler.schedule_expression
    enabled  = aws_cloudwatch_event_rule.email_scheduler.is_enabled
  }
}
