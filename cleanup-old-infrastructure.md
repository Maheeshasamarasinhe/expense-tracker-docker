# Cleanup Old Infrastructure

Before running the next Jenkins build, you need to clean up the old EC2 instance that was in the different VPC.

## Step 1: Terminate the Old EC2 Instance via AWS Console

1. Go to AWS Console → EC2 → Instances
2. Find instance `i-09894d30a2186f7d9` (expense-tracker-server)
3. Right-click → Instance State → Terminate
4. Confirm termination

## Step 2: Release the Old Elastic IP (if any)

1. Go to AWS Console → EC2 → Elastic IPs
2. Find any EIPs not associated with running instances
3. Right-click → Release Elastic IP address
4. Confirm release

## Step 3: Delete Old VPC Resources (if you created them manually)

1. Go to AWS Console → VPC
2. Delete any VPCs named "expense-tracker-vpc" or with tag "expense-tracker"
3. This will also delete associated subnets, route tables, and internet gateways

## Step 4: Clean Up Terraform State in Jenkins

You have two options:

### Option A: Delete Terraform State (Fresh Start)
On your Jenkins server or local WSL:
```bash
cd /var/lib/jenkins/workspace/devops\ final/infrastructure
rm -rf .terraform terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
```

### Option B: Use Terraform Destroy
On your Jenkins server or local WSL:
```bash
cd /var/lib/jenkins/workspace/devops\ final/infrastructure
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_DEFAULT_REGION=us-east-1
terraform destroy -auto-approve
```

## Step 5: Run Jenkins Build

After cleanup, run the Jenkins build again. This time it will:
1. Create a brand new VPC and networking
2. Create a fresh EC2 instance in the new VPC
3. Attach an Elastic IP to the new instance
4. SSH will work because everything is in the same VPC

## Important Notes

- The new EC2 instance will have a different instance ID
- You'll get a new Elastic IP address
- Make sure the SSH key "expense-tracker-key" exists in your AWS account in us-east-1 region
- The build should succeed this time because the instance will be in the correct VPC with the correct security group
