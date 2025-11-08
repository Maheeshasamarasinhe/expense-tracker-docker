pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'your-registry'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Maheeshasamarasinhe/expense-tracker.git'
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
                sh 'docker-compose up --build -d'
                sh 'sleep 30'  // Wait for services to start
                sh 'curl -f http://localhost:4000/api/debug/users || exit 1'
            }
        }
        
        stage('Deploy') {
            steps {
                sh 'docker-compose up --build -d'
            }
        }
    }
    
    post {
        always {
            sh 'docker-compose down'
        }
    }
}