pipeline {
    agent any
    
    environment {
        IMAGE_TAG = "${BUILD_NUMBER}"  // Use Jenkins build number as Docker tag
    }
    
    stages {
        stage('Checkout') {
            steps {
                // Checkout main branch of your repo
                git branch: 'main', url: 'https://github.com/Maheeshasamarasinhe/expense-tracker-docker.git'
            }
        }
        
        stage('Build Images') {
            parallel {
                stage('Backend') {
                    steps {
                        script {
                            sh 'docker build -t expense-backend:${IMAGE_TAG} ./backend'
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        script {
                            sh 'docker build -t expense-frontend:${IMAGE_TAG} ./frontend'
                        }
                    }
                }
                stage('Database') {
                    steps {
                        script {
                            sh 'docker pull mongo:latest'
                            sh 'docker tag mongo:latest expense-mongodb:${IMAGE_TAG}'
                        }
                    }
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    // Start services in detached mode
                    sh 'docker-compose up --build -d'
                    
                    // Wait for services to start
                    sh 'sleep 30'
                    
                    // Run a simple health check (adjust URL to your API)
                    sh 'curl -f http://localhost:4000/api/debug/users || exit 1'
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    // Deploy services (rebuild if necessary)
                    sh 'docker-compose up --build -d'
                }
            }
        }
    }
    
    post {
        always {
            // Stop and remove containers to clean up
            sh 'docker-compose down'
        }
        success {
            echo "Build, test, and deploy completed successfully!"
        }
        failure {
            echo "Build or test failed. Check the logs above."
        }
    }
}
