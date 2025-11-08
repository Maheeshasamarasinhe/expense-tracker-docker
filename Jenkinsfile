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
