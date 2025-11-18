# Lambda Function for Email Handling

# IAM Role for Lambda
resource "aws_iam_role" "lambda_email_role" {
  name = "ticketsync-email-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "TicketSync Email Lambda Role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda - CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_email_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Lambda - SES Access
resource "aws_iam_policy" "lambda_ses_policy" {
  name        = "ticketsync-lambda-ses-policy"
  description = "Allow Lambda to send emails via SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ses" {
  role       = aws_iam_role.lambda_email_role.name
  policy_arn = aws_iam_policy.lambda_ses_policy.arn
}

# IAM Policy for Lambda - DynamoDB Access (if needed in future)
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "ticketsync-lambda-dynamodb-policy"
  description = "Allow Lambda to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.tickets.arn,
          "${aws_dynamodb_table.users.arn}/index/*",
          "${aws_dynamodb_table.tickets.arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_email_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Package Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/email_handler.py"
  output_path = "${path.module}/../lambda/email_handler.zip"
}

# Lambda Function
resource "aws_lambda_function" "email_handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ticketsync-email-handler"
  role            = aws_iam_role.lambda_email_role.arn
  handler         = "email_handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      SENDER_EMAIL = "csaputra@ucsd.edu"
    }
  }

  tags = {
    Name        = "TicketSync Email Handler"
    Environment = var.environment
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.email_handler.function_name}"
  retention_in_days = 7

  tags = {
    Name        = "TicketSync Email Lambda Logs"
    Environment = var.environment
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "email_api" {
  name        = "ticketsync-email-api"
  description = "API Gateway for TicketSync Email Service"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "TicketSync Email API"
    Environment = var.environment
  }
}

# API Gateway Resource
resource "aws_api_gateway_resource" "email_resource" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  parent_id   = aws_api_gateway_rest_api.email_api.root_resource_id
  path_part   = "send-email"
}

# API Gateway POST Method
resource "aws_api_gateway_method" "email_post" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway OPTIONS Method (for CORS)
resource "aws_api_gateway_method" "email_options" {
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  resource_id   = aws_api_gateway_resource.email_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# API Gateway Integration for POST
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.email_api.id
  resource_id             = aws_api_gateway_resource.email_resource.id
  http_method             = aws_api_gateway_method.email_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.email_handler.invoke_arn
}

# API Gateway Integration for OPTIONS (CORS)
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.email_resource.id
  http_method = aws_api_gateway_method.email_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# API Gateway Method Response for OPTIONS
resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.email_resource.id
  http_method = aws_api_gateway_method.email_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# API Gateway Integration Response for OPTIONS
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id
  resource_id = aws_api_gateway_resource.email_resource.id
  http_method = aws_api_gateway_method.email_options.http_method
  status_code = aws_api_gateway_method_response.options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.email_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "email_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.email_api.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "email_api_stage" {
  deployment_id = aws_api_gateway_deployment.email_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.email_api.id
  stage_name    = var.environment

  tags = {
    Name        = "TicketSync Email API ${var.environment} Stage"
    Environment = var.environment
  }
}

# Outputs
output "api_gateway_url" {
  description = "API Gateway endpoint URL for sending emails"
  value       = "${aws_api_gateway_stage.email_api_stage.invoke_url}/send-email"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.email_handler.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.email_handler.arn
}
