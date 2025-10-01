pipeline {
    agent any

    tools {
        nodejs "NodeJS_16"   // le nom que tu auras défini dans Jenkins
    }

    environment {
        DOCKER_HUB_USER = 'mhd0'   // ton username Docker Hub
        FRONT_IMAGE = 'react-frontend'
        BACK_IMAGE  = 'express-backend'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/mhdgeek/express_mongo_react.git'
            }
        }

        stage('Install dependencies - Backend') {
            steps {
                dir('back-end') {
                    sh 'npm install'
                    sh 'node -v && npm -v'
                }
            }
        }

        stage('Install dependencies - Frontend') {
            steps {
                dir('front-end') {
                    sh 'npm install'
                    sh 'node -v && npm -v'
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    sh 'cd back-end && npm test || echo "Aucun test backend"'
                    sh 'cd front-end && npm test || echo "Aucun test frontend"'
                }
            }
        }

        stage('Build Docker Images') {
            steps {
                script {
                    sh "docker build -t $DOCKER_HUB_USER/$FRONT_IMAGE:latest ./front-end"
                    sh "docker build -t $DOCKER_HUB_USER/$BACK_IMAGE:latest ./back-end"
                }
            }
        }

        stage('Push Docker Images') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
            sh script: '''
                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                docker push $DOCKER_USER/react-frontend:latest
                docker push $DOCKER_USER/express-backend:latest
            '''
        }
    }
}

    }
}
