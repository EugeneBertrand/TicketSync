import json
import boto3
from botocore.exceptions import ClientError
from datetime import datetime

ses = boto3.client('ses')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('tickets_test')

def lambda_handler(event, context):
    """
    Lambda function to send email with top 3 highest priority tickets
    No input required - automatically queries DynamoDB and sends email
    """

    SENDER = "clarissaaurel1001@gmail.com"
    RECIPIENT = "clarissauniversitystuff@gmail.com"  # Change this to admin email

    try:
        # Query DynamoDB for all tickets
        response = table.scan()
        tickets = response.get('Items', [])

        # Filter for HIGH priority tickets and sort by timestamp (most recent first)
        high_priority_tickets = [t for t in tickets if t.get('priority') == 'HIGH']
        high_priority_tickets.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

        # Get top 3
        top_tickets = high_priority_tickets[:3]

        if not top_tickets:
            # No high priority tickets, get top 3 by priority order
            priority_order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2}
            tickets.sort(key=lambda x: (
                priority_order.get(x.get('priority', 'LOW'), 3),
                x.get('timestamp', '')
            ), reverse=False)
            top_tickets = tickets[:3]

        # Format HTML email body
        html_body = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    background-color: #f5f5f5;
                    margin: 0;
                    padding: 20px;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    background-color: white;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    overflow: hidden;
                }}
                .header {{
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 30px;
                    text-align: center;
                }}
                .header h1 {{
                    margin: 0;
                    font-size: 24px;
                }}
                .header p {{
                    margin: 10px 0 0 0;
                    opacity: 0.9;
                    font-size: 14px;
                }}
                .content {{
                    padding: 30px;
                }}
                .ticket-card {{
                    background: #f8f9fa;
                    border-left: 4px solid #667eea;
                    padding: 20px;
                    margin-bottom: 20px;
                    border-radius: 5px;
                }}
                .ticket-card.high {{
                    border-left-color: #dc3545;
                    background: #fff5f5;
                }}
                .ticket-card.medium {{
                    border-left-color: #ffc107;
                    background: #fffbf0;
                }}
                .ticket-card.low {{
                    border-left-color: #28a745;
                    background: #f0fff4;
                }}
                .ticket-header {{
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 15px;
                }}
                .ticket-number {{
                    font-size: 18px;
                    font-weight: bold;
                    color: #333;
                }}
                .priority-badge {{
                    padding: 5px 12px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: bold;
                    text-transform: uppercase;
                }}
                .priority-high {{
                    background: #dc3545;
                    color: white;
                }}
                .priority-medium {{
                    background: #ffc107;
                    color: #333;
                }}
                .priority-low {{
                    background: #28a745;
                    color: white;
                }}
                .ticket-title {{
                    font-size: 16px;
                    font-weight: 600;
                    color: #333;
                    margin-bottom: 10px;
                }}
                .ticket-description {{
                    color: #666;
                    line-height: 1.5;
                    margin-bottom: 15px;
                }}
                .ticket-meta {{
                    display: flex;
                    flex-wrap: wrap;
                    gap: 15px;
                    font-size: 13px;
                    color: #888;
                }}
                .meta-item {{
                    display: flex;
                    align-items: center;
                }}
                .meta-label {{
                    font-weight: 600;
                    margin-right: 5px;
                }}
                .sentiment {{
                    padding: 3px 8px;
                    border-radius: 3px;
                    font-size: 11px;
                    font-weight: bold;
                }}
                .sentiment-positive {{
                    background: #d4edda;
                    color: #155724;
                }}
                .sentiment-negative {{
                    background: #f8d7da;
                    color: #721c24;
                }}
                .sentiment-neutral {{
                    background: #d1ecf1;
                    color: #0c5460;
                }}
                .sentiment-mixed {{
                    background: #fff3cd;
                    color: #856404;
                }}
                .summary {{
                    background: #f8f9fa;
                    padding: 20px;
                    border-radius: 5px;
                    margin-top: 20px;
                }}
                .summary h3 {{
                    margin: 0 0 15px 0;
                    color: #333;
                    font-size: 16px;
                }}
                .summary-stats {{
                    display: flex;
                    justify-content: space-around;
                    text-align: center;
                }}
                .stat {{
                    flex: 1;
                }}
                .stat-number {{
                    font-size: 28px;
                    font-weight: bold;
                    color: #667eea;
                }}
                .stat-label {{
                    font-size: 12px;
                    color: #888;
                    text-transform: uppercase;
                }}
                .footer {{
                    text-align: center;
                    padding: 20px;
                    color: #888;
                    font-size: 12px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚨 Priority Tickets Alert</h1>
                    <p>Generated on {datetime.utcnow().strftime('%B %d, %Y at %H:%M:%S')} UTC</p>
                </div>
                <div class="content">
        """

        # Add ticket cards
        for i, ticket in enumerate(top_tickets, 1):
            priority = ticket.get('priority', 'LOW')
            priority_class = priority.lower()
            sentiment = ticket.get('sentiment', 'NEUTRAL')
            sentiment_class = sentiment.lower()

            html_body += f"""
                    <div class="ticket-card {priority_class}">
                        <div class="ticket-header">
                            <span class="ticket-number">#{i} Ticket {ticket.get('ticket_id', 'N/A')[:8]}</span>
                            <span class="priority-badge priority-{priority_class}">{priority}</span>
                        </div>
                        <div class="ticket-title">{ticket.get('title', 'N/A')}</div>
                        <div class="ticket-description">{ticket.get('description', 'N/A')}</div>
                        <div class="ticket-meta">
                            <div class="meta-item">
                                <span class="meta-label">Sentiment:</span>
                                <span class="sentiment sentiment-{sentiment_class}">{sentiment}</span>
                            </div>
                            <div class="meta-item">
                                <span class="meta-label">Status:</span>
                                <span>{ticket.get('status', 'N/A')}</span>
                            </div>
                            <div class="meta-item">
                                <span class="meta-label">Created:</span>
                                <span>{ticket.get('timestamp', 'N/A')}</span>
                            </div>
                        </div>
                    </div>
            """

        # Add summary
        html_body += f"""
                    <div class="summary">
                        <h3>Summary</h3>
                        <div class="summary-stats">
                            <div class="stat">
                                <div class="stat-number">{len(tickets)}</div>
                                <div class="stat-label">Total Tickets</div>
                            </div>
                            <div class="stat">
                                <div class="stat-number">{len(high_priority_tickets)}</div>
                                <div class="stat-label">High Priority</div>
                            </div>
                            <div class="stat">
                                <div class="stat-number">{len(top_tickets)}</div>
                                <div class="stat-label">In This Report</div>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="footer">
                    <p>This is an automated alert from TicketSync</p>
                </div>
            </div>
        </body>
        </html>
        """

        subject = f"⚠️ Alert: {len(high_priority_tickets)} High Priority Tickets Require Attention"

        # Send email using SES with HTML
        response = ses.send_email(
            Source=SENDER,
            Destination={
                'ToAddresses': [RECIPIENT]
            },
            Message={
                'Subject': {
                    'Data': subject,
                    'Charset': 'UTF-8'
                },
                'Body': {
                    'Html': {
                        'Data': html_body,
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
                'messageId': response['MessageId'],
                'ticketsSent': len(top_tickets),
                'highPriorityCount': len(high_priority_tickets)
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
