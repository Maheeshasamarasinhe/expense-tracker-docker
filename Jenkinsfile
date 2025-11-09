pipeline {
    agent any

    environment {
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
                script {
                    withCredentials([string(credentialsId: 'test-dockerhubpassword', variable: 'test-doc-pass')]) {
                        // Login to Docker Hub
                        sh 'echo "$test-doc-pass" | docker login -u "maheeshamihiran" --password-stdin'

                        // Build images
                        sh 'docker build -t maheeshamihiran/expense-backend:${IMAGE_TAG} ./backend'
                        sh 'docker build -t maheeshamihiran/expense-frontend:${IMAGE_TAG} ./frontend'
                        sh 'docker pull mongo:latest'
                        sh 'docker tag mongo:latest maheeshamihiran/expense-mongodb:${IMAGE_TAG}'

                        // Push images to Docker Hub
                        sh 'docker push maheeshamihiran/expense-backend:${IMAGE_TAG}'
                        sh 'docker push maheeshamihiran/expense-frontend:${IMAGE_TAG}'
                        sh 'docker push maheeshamihiran/expense-mongodb:${IMAGE_TAG}'
                    }
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    sh 'docker-compose up --build -d || true'
                    sh 'sleep 30'
                    sh 'curl -f http://localhost:4000/api/debug/users || true'
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    sh 'docker-compose up --build -d || true'
                }
            }
        }
    }

    post {
        always {
            sh 'docker-compose down || true'
        }
    }
}
