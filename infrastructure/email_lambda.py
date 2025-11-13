import json
import boto3

ses = boto3.client('ses')
dynamodb = boto3.client('dynamodb')
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    """
    Simple Lambda function to send emails using Amazon SES
    
    Event structure:
    {
        "to": "recipient@example.com",
        "subject": "Email subject",
        "body": "Email body text"
    }
    """
    
    SENDER = "csaputra@ucsd.edu"  
    
    try:
        recipient = event.get('to')
        subject = event.get('subject')
        body = event.get('body')
        
        if not all([recipient, subject, body]):
            return {
                'statusCode': 400,
                'body': json.dumps('Missing required fields: to, subject, body')
            }

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
                        'Data': body,
                        'Charset': 'UTF-8'
                    }
                }
            }
        )
                
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Email sent successfully',
                'messageId': response['MessageId']
            })
        }
        
    except ClientError as e:
        print(f"Error sending email: {e.response['Error']['Message']}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': e.response['Error']['Message']
            })
        }
    
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
