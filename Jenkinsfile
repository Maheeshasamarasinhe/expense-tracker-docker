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
                                
                                # Check if we need to force recreate the EC2 instance
                                # This file is created when SSH fails repeatedly
                                if [ -f "../.force_recreate_ec2" ]; then
                                    echo "⚠️  Force recreate flag detected. Tainting EC2 instance..."
                                    terraform taint aws_instance.app_server || echo "Instance not yet in state, skipping taint"
                                    rm -f "../.force_recreate_ec2"
                                fi
                                
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
                                INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
                                echo "  Current instance state: $INSTANCE_STATE"
                                aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,VpcId,SubnetId]' --output table || echo "Could not query AWS"
                                
                                # Handle instance in stopping state - wait for it to finish stopping
                                if [ "$INSTANCE_STATE" = "stopping" ]; then
                                    echo ""
                                    echo "⏳ Instance is currently stopping. Waiting for it to fully stop..."
                                    aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID
                                    echo "✅ Instance has stopped."
                                    INSTANCE_STATE="stopped"
                                fi
                                
                                # Handle instance in stopped state - start it
                                if [ "$INSTANCE_STATE" = "stopped" ]; then
                                    echo ""
                                    echo "🚀 Instance is stopped. Starting instance $INSTANCE_ID..."
                                    aws ec2 start-instances --instance-ids $INSTANCE_ID
                                    
                                    echo "Waiting for instance to be running..."
                                    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
                                    echo "✅ Instance is now running."
                                    
                                    # Get the updated public IP
                                    sleep 10
                                    NEW_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
                                    echo "  Public IP: $NEW_IP"
                                    
                                    # Update INSTANCE_IP if it changed
                                    if [ -n "$NEW_IP" ] && [ "$NEW_IP" != "None" ]; then
                                        INSTANCE_IP=$NEW_IP
                                        # Update Ansible inventory with new IP
                                        echo "[ec2_instances]" > ../ansible/inventory
                                        echo "${INSTANCE_IP} ansible_user=ubuntu ansible_ssh_private_key_file=./ssh_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory
                                        echo "Updated Ansible inventory with IP: $INSTANCE_IP"
                                    fi
                                fi
                                
                                # Check if SSH key exists and has correct permissions
                                if [ ! -f "$SSH_KEY" ]; then
                                    echo "❌ SSH key not found at $SSH_KEY"
                                    exit 1
                                fi
                                chmod 600 "$SSH_KEY"
                                
                                # Check instance status and handle impaired state
                                echo ""
                                echo "Checking EC2 instance health status..."
                                STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null || echo "unknown")
                                SYS_STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0].SystemStatus.Status' --output text 2>/dev/null || echo "unknown")
                                echo "  Instance Status: $STATUS, System Status: $SYS_STATUS"
                                
                                # If instance is impaired, stop and start it
                                if [ "$STATUS" = "impaired" ] || [ "$SYS_STATUS" = "impaired" ]; then
                                    echo ""
                                    echo "⚠️  Instance is IMPAIRED! Performing stop/start cycle to recover..."
                                    echo "Stopping instance $INSTANCE_ID..."
                                    aws ec2 stop-instances --instance-ids $INSTANCE_ID
                                    
                                    echo "Waiting for instance to stop..."
                                    aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID
                                    echo "✅ Instance stopped."
                                    
                                    echo "Starting instance $INSTANCE_ID..."
                                    aws ec2 start-instances --instance-ids $INSTANCE_ID
                                    
                                    echo "Waiting for instance to be running..."
                                    aws ec2 wait instance-running --instance-ids $INSTANCE_ID
                                    echo "✅ Instance is running again."
                                    
                                    # Get the new public IP (may change after stop/start without Elastic IP)
                                    sleep 10
                                    NEW_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
                                    echo "  New Public IP: $NEW_IP"
                                    
                                    # Update INSTANCE_IP if it changed
                                    if [ -n "$NEW_IP" ] && [ "$NEW_IP" != "None" ]; then
                                        INSTANCE_IP=$NEW_IP
                                        # Update Ansible inventory with new IP
                                        echo "[ec2_instances]" > ../ansible/inventory
                                        echo "${INSTANCE_IP} ansible_user=ubuntu ansible_ssh_private_key_file=./ssh_key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> ../ansible/inventory
                                        echo "Updated Ansible inventory with new IP: $INSTANCE_IP"
                                    fi
                                fi
                                
                                # Wait for instance status checks to pass
                                echo ""
                                echo "Waiting for EC2 instance status checks to pass..."
                                for i in {1..60}; do
                                    STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null || echo "unknown")
                                    SYS_STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0].SystemStatus.Status' --output text 2>/dev/null || echo "unknown")
                                    echo "  [$i/60] Instance Status: $STATUS, System Status: $SYS_STATUS"
                                    if [ "$STATUS" = "ok" ] && [ "$SYS_STATUS" = "ok" ]; then
                                        echo "✅ Instance status checks passed!"
                                        break
                                    fi
                                    if [ "$STATUS" = "impaired" ] || [ "$SYS_STATUS" = "impaired" ]; then
                                        echo "❌ Instance is still impaired after recovery attempt"
                                        echo "Please check AWS Console for details or terminate and recreate the instance"
                                        exit 1
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
                                    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Testing connection to $INSTANCE_IP..."
                                    
                                    # First check if port 22 is open using nc (faster than SSH)
                                    echo "  Checking if port 22 is open..."
                                    if ! timeout 5 bash -c "echo >/dev/tcp/$INSTANCE_IP/22" 2>/dev/null; then
                                        echo "  ⏳ Port 22 not yet open, waiting ${WAIT_INTERVAL}s..."
                                        sleep $WAIT_INTERVAL
                                        ATTEMPT=$((ATTEMPT + 1))
                                        continue
                                    fi
                                    echo "  ✅ Port 22 is open!"
                                    
                                    # Port is open, now try SSH connection with longer timeout
                                    echo "  Testing SSH authentication..."
                                    if timeout 30 ssh -i "$SSH_KEY" \
                                        -o StrictHostKeyChecking=no \
                                        -o UserKnownHostsFile=/dev/null \
                                        -o ConnectTimeout=10 \
                                        -o ServerAliveInterval=5 \
                                        -o ServerAliveCountMax=3 \
                                        -o BatchMode=yes \
                                        -o PreferredAuthentications=publickey \
                                        ubuntu@$INSTANCE_IP "echo 'SSH connection successful'" 2>&1; then
                                        echo "✅ EC2 instance is ready and accessible!"
                                        exit 0
                                    fi
                                    
                                    echo "  SSH connection failed, SSH daemon may still be starting..."
                                    
                                    # Check if instance is still running
                                    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
                                    echo "   Instance state: $INSTANCE_STATE"
                                    
                                    if [ "$INSTANCE_STATE" != "running" ]; then
                                        echo "❌ Instance is not in running state: $INSTANCE_STATE"
                                        exit 1
                                    fi
                                    
                                    # After 20 attempts (200s), try rebooting the instance to fix SSH
                                    if [ $ATTEMPT -eq 20 ]; then
                                        echo ""
                                        echo "⚠️  SSH still not accessible after 20 attempts. Rebooting instance to recover..."
                                        aws ec2 reboot-instances --instance-ids $INSTANCE_ID
                                        echo "Waiting 60 seconds for instance to reboot..."
                                        sleep 60
                                    fi
                                    
                                    echo "⏳ Not ready yet, waiting ${WAIT_INTERVAL}s before retry..."
                                    sleep $WAIT_INTERVAL
                                    ATTEMPT=$((ATTEMPT + 1))
                                done
                                
                                echo "❌ EC2 instance did not become accessible after $MAX_ATTEMPTS attempts (${MAX_ATTEMPTS}*${WAIT_INTERVAL}s = $((MAX_ATTEMPTS*WAIT_INTERVAL))s total)"
                                echo "Collecting debug information..."
                                aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0]' || echo "Could not get instance status"
                                
                                # Create flag to force EC2 recreation on next build
                                echo "Creating flag to force EC2 recreation on next build..."
                                touch ../.force_recreate_ec2
                                
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
