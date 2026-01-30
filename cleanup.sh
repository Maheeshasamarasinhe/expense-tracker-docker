#!/bin/bash

# Expense Tracker - Cleanup Script
# This script destroys all AWS resources created by Terraform

set -e

echo "======================================"
echo "Expense Tracker Cleanup Script"
echo "======================================"

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}WARNING: This will destroy all AWS resources!${NC}"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

cd infrastructure

echo -e "${YELLOW}Destroying infrastructure...${NC}"
terraform destroy -auto-approve

echo -e "${RED}All resources have been destroyed.${NC}"
echo "======================================"
