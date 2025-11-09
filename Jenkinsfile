pipeline {
    agent any

    environment {
        DOCKER_USERNAME = 'maheeshamihiran'   // ✅ Your Docker Hub username
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Maheeshasamarasinhe/expense-tracker-docker.git'
            }
        }

        stage('Build and Push Images') {
            steps {
                withCredentials([string(credentialsId: 'test-dockerhubpassword', variable: 'test-dockerhubpass')]) {
                    script {
                        // 🔐 Login to Docker Hub securely
                        sh 'echo "$test-dockerhubpass" | docker login -u "$DOCKER_USERNAME" --password-stdin'

                        // 🛠️ Build Docker images
                        sh 'docker build -t $DOCKER_USERNAME/expense-backend:$IMAGE_TAG ./backend'
                        sh 'docker build -t $DOCKER_USERNAME/expense-frontend:$IMAGE_TAG ./frontend'

                        // 🗃️ Pull latest Mongo image and tag it
                        sh 'docker pull mongo:latest'
                        sh 'docker tag mongo:latest $DOCKER_USERNAME/expense-mongodb:$IMAGE_TAG'

                        // 🚀 Push all images to Docker Hub
                        sh 'docker push $DOCKER_USERNAME/expense-backend:$IMAGE_TAG'
                        sh 'docker push $DOCKER_USERNAME/expense-frontend:$IMAGE_TAG'
                        sh 'docker push $DOCKER_USERNAME/expense-mongodb:$IMAGE_TAG'

                        // 🧹 Logout after push
                        sh 'docker logout'
                    }
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    echo '🧪 Starting containers for testing...'
                    sh 'docker-compose up --build -d || true'
                    sh 'sleep 30'
                    sh 'curl -f http://localhost:4000/api/debug/users || true'
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    echo '🚀 Deploying application...'
                    sh 'docker-compose up --build -d || true'
                }
            }
        }
    }

    post {
        always {
            script {
                echo '🧹 Cleaning up containers...'
                sh 'docker-compose down || true'
            }
        }
    }
}
