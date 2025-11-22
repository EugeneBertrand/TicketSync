resource "aws_dynamodb_table" "tickets_test" {
  name           = "tickets_test"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ticket_id"

  attribute {
    name = "ticket_id"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Name        = "Tickets Test Table"
  }
}
