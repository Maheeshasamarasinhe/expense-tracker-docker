# Expense Tracker - CI/CD Deployment Guide

## 🚀 Deployment Pipeline Flow

```
Jenkins (CI - Build & Push Images)
   ↓
Terraform → Creates AWS Infrastructure (VPC, EC2, Security Groups)
   ↓
Ansible → Configures EC2 (Install Docker, Docker Compose)
   ↓
Docker Compose → Runs your application on EC2
```

## 📋 Prerequisites

### 1. Install Required Tools (WSL)
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Ansible
sudo apt install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y

# Install Python dependencies
pip3 install boto3 botocore
```

### 2. Configure AWS Credentials
```bash
# Configure AWS CLI
aws configure

# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Output format: json
```

### 3. Generate SSH Key Pair
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/expense-tracker-key -N ""

# Rename for AWS
mv ~/.ssh/expense-tracker-key ~/.ssh/expense-tracker-key.pem
chmod 400 ~/.ssh/expense-tracker-key.pem

# Copy public key
cp ~/.ssh/expense-tracker-key.pub ~/.ssh/id_rsa.pub
```

## 🛠️ Manual Deployment (Testing)

### Step 1: Terraform - Provision Infrastructure
```bash
cd infrastructure

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply -auto-approve

# Get instance IP
terraform output instance_public_ip
```

### Step 2: Generate Ansible Inventory
```bash
cd ../ansible

# Create inventory file with EC2 IP
echo "[ec2_instances]" > inventory
cd ../infrastructure
terraform output -raw instance_public_ip >> ../ansible/inventory
```

### Step 3: Configure EC2
```bash
cd ../ansible

# Install Docker and Docker Compose on EC2
ansible-playbook -i inventory configure-ec2.yml
```

### Step 4: Deploy Application
```bash
# Deploy application with Docker Compose
ansible-playbook -i inventory deploy.yml
```

### Step 5: Access Application
```bash
# Get instance IP
cd ../infrastructure
INSTANCE_IP=$(terraform output -raw instance_public_ip)

echo "Frontend: http://$INSTANCE_IP:3000"
echo "Backend: http://$INSTANCE_IP:4000"
```

## 🤖 Automated Deployment (Using Script)

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

## 🔄 Jenkins Pipeline (Automated)

The Jenkinsfile includes these stages:
1. **Checkout** - Clone repository
2. **Build Images** - Build Docker images
3. **Push Images** - Push to Docker Hub
4. **Terraform** - Provision AWS infrastructure
5. **Generate Inventory** - Create Ansible inventory
6. **Configure EC2** - Install Docker via Ansible
7. **Deploy** - Run application via Ansible

### Jenkins Configuration

1. Install Jenkins Plugins:
   - Docker Pipeline
   - Terraform
   - Ansible

2. Add Credentials in Jenkins:
   - Docker Hub credentials (ID: `dockerhub`)
   - AWS credentials
   - SSH private key (`expense-tracker-key.pem`)

3. Create Pipeline Job:
   - Point to your Git repository
   - Use Jenkinsfile

## 📁 Project Structure

```
myApp/
├── infrastructure/          # Terraform files
│   ├── main.tf             # AWS resources
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── terraform.tfvars    # Variable values
├── ansible/                # Ansible files
│   ├── ansible.cfg         # Ansible configuration
│   ├── inventory           # EC2 hosts (auto-generated)
│   ├── configure-ec2.yml   # EC2 setup playbook
│   └── deploy.yml          # Deployment playbook
├── backend/                # Backend code
├── frontend/               # Frontend code
├── docker-compose.yaml     # Docker Compose config
├── Jenkinsfile            # Jenkins pipeline
├── deploy.sh              # Deployment script
└── cleanup.sh             # Cleanup script
```

## 🧹 Cleanup Resources

```bash
# Destroy all AWS resources
chmod +x cleanup.sh
./cleanup.sh

# Or manually
cd infrastructure
terraform destroy -auto-approve
```

## 🔧 Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connection
ssh -i ~/.ssh/expense-tracker-key.pem ubuntu@<INSTANCE_IP>

# Check key permissions
chmod 400 ~/.ssh/expense-tracker-key.pem
```

### Ansible Connection Issues
```bash
# Test Ansible connectivity
ansible -i inventory ec2_instances -m ping

# Verbose mode for debugging
ansible-playbook -i inventory deploy.yml -vvv
```

### Check Application Logs
```bash
# SSH into EC2
ssh -i ~/.ssh/expense-tracker-key.pem ubuntu@<INSTANCE_IP>

# View Docker logs
docker-compose logs -f

# Check running containers
docker ps
```

## 💰 AWS Costs

**Free Tier Resources:**
- t2.micro EC2 instance (750 hours/month)
- 5 GB of standard storage
- 15 GB of bandwidth

**Estimated Costs (if exceeding free tier):**
- t2.medium: ~$30/month
- Elastic IP: Free if attached
- Data transfer: ~$0.09/GB

## 📝 Notes

- Default region: `us-east-1`
- Instance type: `t2.medium` (can change to `t2.micro` for free tier)
- SSH user: `ubuntu`
- Ports: 3000 (frontend), 4000 (backend), 27017 (MongoDB)

## 🔐 Security Best Practices

1. **Restrict SSH access** - Change security group from `0.0.0.0/0` to your IP
2. **Use environment variables** - Don't commit sensitive data
3. **Enable HTTPS** - Use Let's Encrypt for SSL
4. **Regular updates** - Keep EC2 instance updated
5. **Backup data** - Regular database backups

## 📞 Support

For issues, check:
- Terraform logs
- Ansible output
- Jenkins console
- EC2 instance logs via SSH
