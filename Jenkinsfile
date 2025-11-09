pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'maheeshamihiran' // replace with your Docker Hub username
        IMAGE_TAG = "${BUILD_NUMBER}" // automatically increments each build
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
                    sh 'echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin'
                    sh "docker push ${DOCKER_HUB_USER}/expense-backend:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_HUB_USER}/expense-frontend:${IMAGE_TAG}"
                    sh "docker push ${DOCKER_HUB_USER}/expense-mongodb:${IMAGE_TAG}"
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
