#!/bin/bash

# Check if EC2 instance already exists before running Terraform

echo "Checking for existing expense-tracker-server instances..."

EXISTING_INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=expense-tracker-server" \
            "Name=instance-state-name,Values=running,pending,stopping,stopped" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table)

if [ -n "$EXISTING_INSTANCES" ]; then
    echo "========================================"
    echo "⚠️  WARNING: Existing EC2 instances found!"
    echo "========================================"
    echo "$EXISTING_INSTANCES"
    echo ""
    echo "Terraform will use the existing instance instead of creating a new one."
    echo ""
    read -p "Continue with Terraform? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled."
        exit 1
    fi
else
    echo "✅ No existing instances found. Terraform will create a new EC2 instance."
fi

echo "Proceeding with Terraform..."
