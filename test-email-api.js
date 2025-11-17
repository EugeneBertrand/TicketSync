// Test script for the email API
// Run with: node test-email-api.js

const API_URL = 'https://qu54gkl5y0.execute-api.us-east-1.amazonaws.com/dev/send-email';

async function testEmailAPI() {
  const emailData = {
    to: 'csaputra@ucsd.edu',  // Change to recipient email
    subject: 'Test Email from TicketSync API',
    body: 'Hello! This is a test email sent from the TicketSync email handler Lambda function via API Gateway.'
  };

  try {
    console.log('Sending email to:', emailData.to);
    console.log('Subject:', emailData.subject);
    console.log('\nMaking request to:', API_URL);

    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(emailData)
    });

    const result = await response.json();

    if (response.ok) {
      console.log('\n✓ Email sent successfully!');
      console.log('Message ID:', result.messageId);
    } else {
      console.error('\n✗ Error sending email:');
      console.error('Status:', response.status);
      console.error('Error:', result.error || result);
    }
  } catch (error) {
    console.error('\n✗ Request failed:');
    console.error(error.message);
  }
}

// Run the test
testEmailAPI();
