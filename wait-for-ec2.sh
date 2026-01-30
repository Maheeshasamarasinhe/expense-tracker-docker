#!/bin/bash

# Wait for EC2 instance to be ready and accessible via SSH

EC2_IP=$1
SSH_KEY=~/.ssh/expense-tracker-key
MAX_RETRIES=30
RETRY_DELAY=10

if [ -z "$EC2_IP" ]; then
    echo "Usage: $0 <EC2_IP>"
    exit 1
fi

echo "Waiting for EC2 instance at $EC2_IP to be ready..."

for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i/$MAX_RETRIES: Testing SSH connection..."
    
    if ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$EC2_IP "echo 'SSH connection successful'" 2>/dev/null; then
        echo "✅ EC2 instance is ready and accessible!"
        exit 0
    fi
    
    echo "⏳ Not ready yet, waiting ${RETRY_DELAY}s before retry..."
    sleep $RETRY_DELAY
done

echo "❌ EC2 instance did not become accessible after $MAX_RETRIES attempts"
exit 1
