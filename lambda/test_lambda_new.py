import json
import uuid
from datetime import datetime
import boto3
import os

# ---------------------------
# Use real DynamoDB table
# ---------------------------
dynamodb = boto3.resource('dynamodb', region_name='us-east-1')  # use your region
comprehend = boto3.client('comprehend')
table_name = "tickets_test"  # your actual table name
table = dynamodb.Table(table_name)

# ---------------------------
# Mock Comprehend function
# ---------------------------
'''def mock_detect_sentiment(text):
    return {
        "Sentiment": "NEUTRAL",
        "SentimentScore": {
            "Positive": 0.1,
            "Negative": 0.2,
            "Neutral": 0.6,
            "Mixed": 0.1
        }
    }'''

# ---------------------------
# Lambda handler
# ---------------------------
def lambda_handler(event, context=None):
    body = json.loads(event.get('body', '{}'))
    title = body.get('title')
    description = body.get('description')

    ticket_id = str(uuid.uuid4())
    priority = "LOW"
    response = comprehend.detect_sentiment(Text=description, LanguageCode='en')
    sentiment = response['Sentiment']
    # Use mock sentiment
    #response = mock_detect_sentiment(description)
    #sentiment = response['Sentiment']

    if sentiment == "NEGATIVE":
        priority = "HIGH"
    elif sentiment in ["NEUTRAL", "MIXED"]:
        priority = "MEDIUM"
    else:
        priority = "LOW"

    # Store in real DynamoDB
    table.put_item(Item={
        'ticket_id': ticket_id,
        'title': title,
        'description': description,
        'sentiment': sentiment,
        'priority': priority,
        'status': 'OPEN',
        'timestamp': datetime.utcnow().isoformat()
    })

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Ticket created",
            "ticket_id": ticket_id,
            "sentiment": sentiment,
            "priority": priority
        })
    }

# ---------------------------
# Test locally
# ---------------------------
if __name__ == "__main__":
    test_event = {
        "body": json.dumps({
            "title": "Server Performance",
            "description": "Server peformance is okay but could be better."
        })
    }

    result = lambda_handler(test_event)
    print("\nLambda output:\n", result)
