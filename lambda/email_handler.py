import json
import boto3
from botocore.exceptions import ClientError

ses = boto3.client('ses')
dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    """
    Lambda function to send emails using Amazon SES
    Accepts POST requests with JSON body containing email details

    Expected body structure:
    {
        "to": "recipient@example.com",
        "subject": "Email subject",
        "body": "Email body text"
    }
    """

    SENDER = "clarissaaurel1001@gmail.com"

    try:
        # Parse the body from API Gateway event
        if 'body' in event:
            if isinstance(event['body'], str):
                body_data = json.loads(event['body'])
            else:
                body_data = event['body']
        else:
            body_data = event

        recipient = body_data.get('to')
        subject = body_data.get('subject')
        email_body = body_data.get('body')

        # Validate required fields
        if not all([recipient, subject, email_body]):
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                'body': json.dumps({
                    'error': 'Missing required fields: to, subject, body'
                })
            }

        # Send email using SES
        response = ses.send_email(
            Source=SENDER,
            Destination={
                'ToAddresses': [recipient]
            },
            Message={
                'Subject': {
                    'Data': subject,
                    'Charset': 'UTF-8'
                },
                'Body': {
                    'Text': {
                        'Data': email_body,
                        'Charset': 'UTF-8'
                    }
                }
            }
        )

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'message': 'Email sent successfully',
                'messageId': response['MessageId']
            })
        }

    except ClientError as e:
        print(f"Error sending email: {e.response['Error']['Message']}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'error': e.response['Error']['Message']
            })
        }

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
