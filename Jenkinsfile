pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'maheeshamihiran' 
        IMAGE_TAG = "${BUILD_NUMBER}" 
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Maheeshasamarasinhe/expense-tracker-docker.git'
            }
        }

        stage('Build Images') {
            parallel {
                stage('Backend') {
                    steps {
                        script {
                            sh "docker build -t ${DOCKER_HUB_USER}/expense-backend:${IMAGE_TAG} ./backend"
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        script {
                            sh "docker build -t ${DOCKER_HUB_USER}/expense-frontend:${IMAGE_TAG} ./frontend"
                        }
                    }
                }
                stage('Database') {
                    steps {
                        script {
                            sh 'docker pull mongo:latest'
                            sh "docker tag mongo:latest ${DOCKER_HUB_USER}/expense-mongodb:${IMAGE_TAG}"
                        }
                    }
                }
            }
        }

        stage('Push Images') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
                    retry(3) {
                        sh '''
                            echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin
                            docker push ${DOCKER_HUB_USER}/expense-backend:${IMAGE_TAG}
                            docker push ${DOCKER_HUB_USER}/expense-frontend:${IMAGE_TAG}
                            docker push ${DOCKER_HUB_USER}/expense-mongodb:${IMAGE_TAG}
                        '''
                    }
                }
            }
        }

        stage('Terraform - Provision Infrastructure') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        dir('infrastructure') {
                            sh '''
                                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                                export AWS_DEFAULT_REGION=us-east-1
                                
                                echo "Initializing Terraform..."
                                terraform init
                                terraform plan -out=tfplan
                                terraform apply -auto-approve tfplan
                                
                                echo "=========================================="
                                echo "Terraform outputs:"
                                terraform output
                                echo "=========================================="
                                
                                # Generate Ansible inventory from Terraform output
                                echo "Generating Ansible inventory..."
                                INSTANCE_IP=$(terraform output -raw instance_public_ip)
                                echo "[ec2_instances]" > ../ansible/inventory
                                echo "${INSTANCE_IP} ansible_user=ubuntu ansible_ssh_private_key_file=./ssh_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory
                                echo "Inventory generated:"
                                cat ../ansible/inventory
                            '''
                        }
                    }
                }
            }
        }

        stage('Verify SSH Key & Inventory') {
            steps {
                script {
                    sh '''
                        echo "Checking generated SSH key..."
                        ls -la ansible/ssh_key.pem
                        
                        echo "Checking Ansible inventory..."
                        cat ansible/inventory
                    '''
                }
            }
        }

        stage('Wait for EC2 to be Ready') {
            steps {
                script {
                    withCredentials([string(credentialsId: 'AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
                                     string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                        dir('infrastructure') {
                            sh '''
                                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                                export AWS_DEFAULT_REGION=us-east-1
                                
                                INSTANCE_IP=$(terraform output -raw instance_public_ip)
                                INSTANCE_ID=$(terraform output -raw instance_id)
                                SSH_KEY="../ansible/ssh_key.pem"
                                
                                echo "=========================================="
                                echo "EC2 Instance Details:"
                                echo "  Instance ID: $INSTANCE_ID"
                                echo "  Public IP: $INSTANCE_IP"
                                echo "  SSH Key: $SSH_KEY"
                                echo "=========================================="
                                
                                # Check instance state in AWS
                                echo "Checking EC2 instance state..."
                                aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,VpcId,SubnetId]' --output table || echo "Could not query AWS"
                                
                                # Check if SSH key exists and has correct permissions
                                if [ ! -f "$SSH_KEY" ]; then
                                    echo "❌ SSH key not found at $SSH_KEY"
                                    exit 1
                                fi
                                chmod 600 "$SSH_KEY"
                                
                                # First, wait for EC2 instance status checks to pass
                                echo ""
                                echo "Waiting for EC2 instance status checks..."
                                for i in {1..30}; do
                                    STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null || echo "unknown")
                                    SYS_STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0].SystemStatus.Status' --output text 2>/dev/null || echo "unknown")
                                    echo "  Instance Status: $STATUS, System Status: $SYS_STATUS"
                                    if [ "$STATUS" = "ok" ] && [ "$SYS_STATUS" = "ok" ]; then
                                        echo "✅ Instance status checks passed!"
                                        break
                                    fi
                                    sleep 5
                                done
                                
                                # Wait for EC2 to be ready with improved diagnostics
                                echo ""
                                echo "Waiting for SSH to be accessible..."
                                MAX_ATTEMPTS=60
                                WAIT_INTERVAL=10
                                ATTEMPT=1
                                
                                while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
                                    echo "----------------------------------------"
                                    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Testing SSH connection to $INSTANCE_IP..."
                                    
                                    # Try SSH connection with verbose error output
                                    if timeout 15 ssh -i "$SSH_KEY" \
                                        -o StrictHostKeyChecking=no \
                                        -o UserKnownHostsFile=/dev/null \
                                        -o ConnectTimeout=5 \
                                        -o BatchMode=yes \
                                        -o PreferredAuthentications=publickey \
                                        ubuntu@$INSTANCE_IP "echo 'SSH connection successful'" 2>&1; then
                                        echo "✅ EC2 instance is ready and accessible!"
                                        exit 0
                                    fi
                                    
                                    # Check if instance is still running
                                    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
                                    echo "   Instance state: $INSTANCE_STATE"
                                    
                                    if [ "$INSTANCE_STATE" != "running" ]; then
                                        echo "❌ Instance is not in running state: $INSTANCE_STATE"
                                        exit 1
                                    fi
                                    
                                    echo "⏳ Not ready yet, waiting ${WAIT_INTERVAL}s before retry..."
                                    sleep $WAIT_INTERVAL
                                    ATTEMPT=$((ATTEMPT + 1))
                                done
                                
                                echo "❌ EC2 instance did not become accessible after $MAX_ATTEMPTS attempts (${MAX_ATTEMPTS}*${WAIT_INTERVAL}s = $((MAX_ATTEMPTS*WAIT_INTERVAL))s total)"
                                echo "Collecting debug information..."
                                aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0]' || echo "Could not get instance status"
                                exit 1
                            '''
                        }
                    }
                }
            }
        }

        stage('Configure EC2 with Ansible') {
            steps {
                script {
                    dir('ansible') {
                        sh '''
                            echo "Running Ansible configuration playbook..."
                            ansible-playbook -i inventory configure-ec2.yml
                        '''
                    }
                }
            }
        }
       
        stage('Deploy Application with Ansible') {
            steps {
                script {
                    // Update docker-compose.hub.yml with the correct image tags
                    sh """
                        sed -i 's|maheeshamihiran/expense-backend:latest|maheeshamihiran/expense-backend:${IMAGE_TAG}|g' docker-compose.hub.yml
                        sed -i 's|maheeshamihiran/expense-frontend:latest|maheeshamihiran/expense-frontend:${IMAGE_TAG}|g' docker-compose.hub.yml
                        echo "Updated docker-compose.hub.yml with tag ${IMAGE_TAG}:"
                        cat docker-compose.hub.yml
                    """
                    dir('ansible') {
                        sh '''
                            echo "Running Ansible deployment playbook..."
                            ansible-playbook -i inventory deploy.yml
                        '''
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    dir('infrastructure') {
                        sh '''
                            INSTANCE_IP=$(terraform output -raw instance_public_ip)
                            echo "Frontend URL: http://$INSTANCE_IP:3000"
                            echo "Backend URL: http://$INSTANCE_IP:4000"
                            echo "Waiting for services to be ready..."
                            sleep 30
                            echo "Testing Frontend..."
                            curl -f http://$INSTANCE_IP:3000 || echo "Frontend not ready yet"
                            echo "Testing Backend..."
                            curl -s http://$INSTANCE_IP:4000/ || echo "Backend not ready yet"
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                dir('infrastructure') {
                    sh '''
                        INSTANCE_IP=$(terraform output -raw instance_public_ip)
                        echo "========================================"
                        echo "Deployment Successful!"
                        echo "Frontend: http://$INSTANCE_IP:3000"
                        echo "Backend: http://$INSTANCE_IP:4000"
                        echo "========================================"
                    '''
                }
            }
        }
        failure {
            echo 'Deployment failed. Check logs above.'
        }
    }
}
