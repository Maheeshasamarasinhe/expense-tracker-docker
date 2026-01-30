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
                                
                                # Wait for EC2 to be ready
                                for i in $(seq 1 30); do
                                    echo "----------------------------------------"
                                    echo "Attempt $i/30: Testing SSH connection to $INSTANCE_IP..."
                                    if ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes ubuntu@$INSTANCE_IP "echo 'SSH connection successful'" 2>/dev/null; then
                                        echo "✅ EC2 instance is ready and accessible!"
                                        exit 0
                                    fi
                                    echo "⏳ Not ready yet, waiting 10s before retry..."
                                    sleep 10
                                done
                                echo "❌ EC2 instance did not become accessible after 30 attempts"
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
                            curl -f http://$INSTANCE_IP:3000 || echo "Frontend not ready yet"
                            curl -f http://$INSTANCE_IP:4000/health || echo "Backend not ready yet"
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
