import boto3

# Initialize the Comprehend client
client = boto3.client("comprehend", region_name="us-east-1")  # match your region

# Example text
text = "I love using AWS! It's amazing."

# Call DetectSentiment
response = client.detect_sentiment(
    Text=text,
    LanguageCode="en"  # English
)

# Print the response
print(response)
