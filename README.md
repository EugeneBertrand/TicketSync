# TicketSync

TicketSync is a customer support platform that allows customers to submit support tickets and administrators to manage and respond to them.

## Features

- **React.js Login Portal**: Choose between client or admin login
- **AWS Cognito Authentication**: Separate user pools for clients and admins
- **AWS S3 Hosting**: Static website hosting for the React application
- **Terraform Infrastructure**: Infrastructure as Code for easy deployment

## Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- AWS Account
- Terraform (v1.0 or higher)
- AWS CLI configured with appropriate credentials

## Setup Instructions

### 1. Deploy Infrastructure with Terraform

1. Navigate to the infrastructure directory:
```bash
cd infrastructure
```

2. Initialize Terraform:
```bash
terraform init
```

3. Review and update the Terraform configuration in `main.tf`:
   - Update the S3 bucket name (must be globally unique)
   - Update the region if needed
   - Update the IAM user name for your teammate

4. Plan the deployment:
```bash
terraform plan
```

5. Apply the infrastructure:
```bash
terraform apply
```

6. After deployment, note the outputs:
   - `client_user_pool_id`
   - `client_user_pool_client_id`
   - `admin_user_pool_id`
   - `admin_user_pool_client_id`
   - `aws_region`
   - `s3_bucket_name`

### 2. Configure React Application

1. Navigate to the project root:
```bash
cd ..
```

2. Create a `.env` file in the root directory:
```bash
cp .env.example .env
```

3. Update the `.env` file with the values from Terraform outputs:
```env
VITE_AWS_REGION=us-east-1
VITE_CLIENT_USER_POOL_ID=<from terraform output>
VITE_CLIENT_USER_POOL_CLIENT_ID=<from terraform output>
VITE_ADMIN_USER_POOL_ID=<from terraform output>
VITE_ADMIN_USER_POOL_CLIENT_ID=<from terraform output>
```

### 3. Install Dependencies and Run Locally

1. Install dependencies:
```bash
npm install
```

2. Run the development server:
```bash
npm run dev
```

3. Open your browser to `http://localhost:5173`

### 4. Build and Deploy to S3

1. Build the application:
```bash
npm run build
```

2. Deploy to S3 (replace `BUCKET_NAME` with your S3 bucket name from Terraform):
```bash
aws s3 sync dist/ s3://BUCKET_NAME --delete
```

3. Your application will be available at the S3 website endpoint (shown in Terraform outputs)

## User Types

### Client Users
- Can sign up and sign in to submit support tickets
- Password requirements: Minimum 8 characters with uppercase, lowercase, numbers, and symbols
- Token validity: 24 hours

### Admin Users
- Can sign up and sign in to manage support tickets
- Password requirements: Minimum 10 characters with uppercase, lowercase, numbers, and symbols
- MFA: Optional (can be enabled)
- Token validity: 8 hours (shorter for security)

## Project Structure

```
TicketSync/
├── infrastructure/
│   └── main.tf          # Terraform infrastructure configuration
├── src/
│   ├── components/
│   │   ├── LoginPortal.jsx      # Main login portal component
│   │   ├── LoginPortal.css      # Login portal styles
│   │   ├── ClientDashboard.jsx  # Client dashboard
│   │   ├── AdminDashboard.jsx   # Admin dashboard
│   │   ├── ProtectedRoute.jsx   # Route protection component
│   │   └── Dashboard.css        # Dashboard styles
│   ├── App.jsx          # Main app component with routing
│   ├── App.css          # App styles
│   ├── main.jsx         # Application entry point
│   └── index.css        # Global styles
├── index.html           # HTML template
├── package.json         # Node.js dependencies
├── vite.config.js       # Vite configuration
└── README.md           # This file
```

## Authentication Flow

1. User selects either "Client Login" or "Admin Login"
2. User can sign up (creates account) or sign in (existing account)
3. For new accounts, user must confirm their email with a confirmation code
4. After authentication, user is redirected to their respective dashboard
5. Authentication state is managed by AWS Amplify and AWS Cognito

## Security Features

- Separate Cognito User Pools for clients and admins
- Password policies enforced by Cognito
- Email verification required for new accounts
- JWT-based authentication tokens
- Protected routes that require authentication
- Token expiration for enhanced security

## Future Enhancements

- Ticket submission functionality
- Ticket management dashboard
- Real-time updates
- Sentiment analysis
- Email notifications
- Multi-factor authentication (MFA) for admins

## Troubleshooting

### Authentication Issues
- Ensure environment variables are correctly set in `.env`
- Verify Cognito User Pool IDs and Client IDs from Terraform outputs
- Check that email verification is working (check spam folder)

### Deployment Issues
- Ensure S3 bucket has proper permissions
- Verify that the bucket is configured for static website hosting
- Check CloudWatch logs for any errors

## License

This project is part of the TicketSync platform.

