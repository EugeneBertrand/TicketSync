import json
import boto3
import os
import uuid
from datetime import datetime
# initialize comprehend, dynamodb, and then the table that stores the results
comprehend = boto3.client('comprehend')
dynamodb = boto3.resource('dynamodb')
# Use a test table
table_name = os.environ.get('DYNAMODB_TABLE', 'tickets_test')
# Use the test AWS profile
#dynamodb = boto3.resource('dynamodb')
#table = dynamodb.Table(table_name)
#table_name = os.environ.get('DYNAMODB_TABLE', 'tickets')
# get the table
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    # gets the title and description from the event body (basically from the frontend)
    body = json.loads(event.get('body', '{}'))
    title = body.get('title')
    description = body.get('description') #this is what we will analyze for sentiment
    # 1️⃣ Generate a unique ticket ID
    ticket_id = str(uuid.uuid4())
    priority = "LOW"
    # Analyze sentiment using AWS Comprehend
    response = comprehend.detect_sentiment(Text=description, LanguageCode='en')
    sentiment = response['Sentiment']
    if(sentiment == "NEGATIVE"):
        priority = "HIGH"
    elif(sentiment == "NEUTRAL" or sentiment == "MIXED"):
        priority = "MEDIUM"
    else:
        priority = "LOW"
    # Store in DynamoDB
    table.put_item(Item={
        'ticket_id': ticket_id,
        'title': title,
        'description': description,
        'sentiment': sentiment,
        'priority': priority,
        'status': 'OPEN',
        'timestamp': datetime.utcnow().isoformat()
    #Python rules base system might be better than this version of sentiment analysis
    # if a ticket is not resolved in X amount of time, it gets the highest priority
    # and then it goes to the front of the queue
    })
    # Return the ticket ID and sentiment analysis result
    return {
        "statusCode": 200,
        "headers": {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "OPTIONS,POST"
        },
        "body": json.dumps({
            "message": "Ticket created",
            "ticket_id": ticket_id,
            "sentiment": sentiment,
            "priority": priority
        })
    }
def update_ticket_status(event, context):
    # loads in the ticket ID and new status from the event body
    body = json.loads(event.get('body', '{}'))
    ticket_id = body.get('ticket_id')
    status = body.get('status')

    table.update_item(
    # finds the ticket by its ID and updates the status
        Key={'ticket_id': ticket_id},
        UpdateExpression="set #s = :status",
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={':status': status},
        )

    return {
        # returns a success message
        "statusCode": 200,
        "headers": {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "OPTIONS,POST"
        },
        "body": json.dumps({"message": "Ticket updated"})
        }
