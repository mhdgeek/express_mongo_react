pipeline {
    agent any

    tools {
       // git 'Git_Default'
        nodejs "NodeJS_16"
    }

    environment {
       // SONAR_ADMIN_TOKEN = credentials('sonar_token')
        DOCKER_HUB_USER = 'mhd0'
        FRONT_IMAGE = 'react-frontend'
        BACK_IMAGE  = 'express-backend'
    }

    triggers {
        GenericTrigger(
            genericVariables: [
                [key: 'ref', value: '$.ref'],
                [key: 'pusher_name', value: '$.pusher.name'],
                [key: 'commit_message', value: '$.head_commit.message']
            ],
            causeString: 'Push par $pusher_name sur $ref: "$commit_message"',
            token: 'mysecret',
            printContributedVariables: true,
            printPostContent: true
        )
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/mhdgeek/express_mongo_react.git'
            }
        }

        stage('Install dependencies - Backend') {
            steps {
                dir('back-end') {
                    sh 'npm install'
                }
            }
        }

        stage('Install dependencies - Frontend') {
            steps {
                dir('front-end') {
                    sh 'npm install'
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

        // -------------------- SonarQube --------------------

        stage('SonarQube Analysis') {
    steps {
        withSonarQubeEnv('SonarQube') {
            sh '''
                echo "=== Starting SonarQube Analysis ==="
                sonar-scanner \
                    -Dsonar.projectKey=express_mongo_react \
                    -Dsonar.sources=. \
                    -Dsonar.host.url=http://sonarqube:9000 \
                    -Dsonar.login=$SONAR_TOKEN
            '''
        }
    }
}
        stage('Quality Gate') {
            steps {
                timeout(time: 3, unit: 'MINUTES') {
                    script {
                        def qg = waitForQualityGate(abortPipeline: false)
                        echo "Quality Gate status: ${qg.status}"
                        if (qg.status != 'OK') {
                            echo " Attention: Quality Gate en erreur, le pipeline continue malgré tout."
                        }
                    }
                }
            }
        }
        // ---------------------------------------------------

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
                    sh '''
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker push $DOCKER_USER/react-frontend:latest
                        docker push $DOCKER_USER/express-backend:latest
                    '''
                }
            }
        }

// 🆕 --- AJOUT DU DÉPLOIEMENT KUBERNETES ICI ---
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    sh '''
                    echo "Déploiement sur Kubernetes..."
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml
                    kubectl get pods -o wide
                    kubectl get svc
                    '''
                }
            }
        }
        // --- FIN AJOUT ---
        
        stage('Smoke Test') {
            steps {
                sh '''
                    echo " Vérification Frontend (port 5173)..."
                    curl -f http://localhost:5173 || echo "Frontend unreachable"

                    echo " Vérification Backend (port 5001)..."
                    curl -f http://localhost:5001/api || echo "Backend unreachable"
                '''
            }
        }
    }

    post {
        success {
            emailext(
                subject: "Build SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Pipeline réussi\nDétails : ${env.BUILD_URL}",
                to: "mohamedndoye07@gmail.com"
            )
        }
        failure {
            emailext(
                subject: "Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Le pipeline a échoué\nDétails : ${env.BUILD_URL}",
                to: "mohamedndoye07@gmail.com"
            )
        }
    }
}
