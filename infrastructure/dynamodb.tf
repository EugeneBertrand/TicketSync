# DynamoDB Table for Users
resource "aws_dynamodb_table" "users" {
  name           = "TicketSync-Users"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "email"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "userType"
    type = "S"
  }

  global_secondary_index {
    name               = "UserTypeIndex"
    hash_key           = "userType"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "TicketSync-Users"
    Environment = "${var.environment}"
  }
}

# DynamoDB Table for Tickets
resource "aws_dynamodb_table" "tickets" {
  name           = "TicketSync-Tickets"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ticketId"
  range_key      = "createdAt"

  attribute {
    name = "ticketId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }
  
  attribute {
    name = "description"
    type = "S"
  }

  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "UserIndex"
    hash_key           = "userId"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "TicketSync-Tickets"
    Environment = "${var.environment}"
  }
}
