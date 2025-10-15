pipeline {
    agent any

    tools {
        nodejs "NodeJS_22"
    }

    environment {
        DOCKER_HUB_USER = 'mhd0'
        FRONT_IMAGE = 'express-mongo-react-frontend'
        BACK_IMAGE  = 'express-mongo-react-backend'
        PATH = "/usr/local/bin:${env.PATH}"
        KUBECONFIG = "/Users/mhd/.kube/config"
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

        stage('Install Dependencies') {
            parallel {
                stage('Backend Dependencies') {
                    steps {
                        dir('back-end') {
                            sh 'npm install'
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    steps {
                        dir('front-end') {
                            sh 'npm install'
                        }
                    }
                }
            }
        }

        stage('Build Applications') {
            parallel {
                stage('Build Backend') {
                    steps {
                        dir('back-end') {
                            sh 'npm run build || echo "Build script may not exist, continuing..."'
                        }
                    }
                }
                stage('Build Frontend') {
                    steps {
                        dir('front-end') {
                            sh 'npm run build'
                        }
                    }
                }
            }
        }

        stage('Build Docker Images') {
            parallel {
                stage('Build Backend Image') {
                    steps {
                        dir('back-end') {
                            sh """
                                docker build -t ${env.DOCKER_HUB_USER}/${env.BACK_IMAGE}:${BUILD_NUMBER} .
                                docker tag ${env.DOCKER_HUB_USER}/${env.BACK_IMAGE}:${BUILD_NUMBER} ${env.DOCKER_HUB_USER}/${env.BACK_IMAGE}:latest
                            """
                        }
                    }
                }
                stage('Build Frontend Image') {
                    steps {
                        dir('front-end') {
                            sh """
                                docker build -t ${env.DOCKER_HUB_USER}/${env.FRONT_IMAGE}:${BUILD_NUMBER} .
                                docker tag ${env.DOCKER_HUB_USER}/${env.FRONT_IMAGE}:${BUILD_NUMBER} ${env.DOCKER_HUB_USER}/${env.FRONT_IMAGE}:latest
                            """
                        }
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    passwordVariable: 'DOCKERHUB_PASSWORD',
                    usernameVariable: 'DOCKERHUB_USERNAME'
                )]) {
                    sh """
                        echo \"${DOCKERHUB_PASSWORD}\" | docker login -u \"${DOCKERHUB_USERNAME}\" --password-stdin
                        docker push ${env.DOCKER_HUB_USER}/${env.BACK_IMAGE}:${BUILD_NUMBER}
                        docker push ${env.DOCKER_HUB_USER}/${env.BACK_IMAGE}:latest
                        docker push ${env.DOCKER_HUB_USER}/${env.FRONT_IMAGE}:${BUILD_NUMBER}
                        docker push ${env.DOCKER_HUB_USER}/${env.FRONT_IMAGE}:latest
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Vérifier que minikube est en cours d'exécution
                    sh 'minikube status || minikube start'
                    
                    // Appliquer les configurations Kubernetes dans l'ordre
                    sh 'kubectl apply -f k8s/mongodb-deployment.yaml'
                    
                    // Attendre que MongoDB soit prêt
                    sh 'sleep 45'
                    
                    // Déployer le backend
                    sh 'kubectl apply -f k8s/backend-deployment.yaml'
                    sh 'sleep 20'
                    
                    // Déployer le frontend
                    sh 'kubectl apply -f k8s/frontend-deployment.yaml'
                    
                    // Attendre que les déploiements soient terminés
                    sh '''
                        kubectl rollout status deployment/backend-deployment --timeout=300s
                        kubectl rollout status deployment/frontend-deployment --timeout=300s
                    '''
                }
            }
        }

       stage('Health Check & Smoke Tests') {
    steps {
        script {
            timeout(time: 3, unit: 'MINUTES') {
                waitUntil {
                    try {
                        echo "🔍 Vérification de la santé des services..."
                        
                        // Méthode avec port-forward pour éviter l'erreur ClusterIP
                        sh '''
                            # Démarrer port-forward en arrière-plan
                            kubectl port-forward service/backend-service 5000:5000 &
                            PF_PID=$!
                            
                            # Attendre que port-forward soit prêt
                            sleep 10
                            
                            # Tester le backend
                            echo "Testing backend via port-forward..."
                            curl -f http://localhost:5000/health || curl -f http://localhost:5000
                            
                            # Arrêter port-forward
                            kill $PF_PID
                            
                            # Tester le frontend avec minikube service
                            echo "Testing frontend..."
                            FRONTEND_URL=$(minikube service frontend-service --url)
                            curl -f $FRONTEND_URL
                        '''
                        
                        return true
                    } catch (Exception e) {
                        echo "⏳ Services pas encore prêts, nouvelle tentative dans 15s..."
                        sleep 15
                        return false
                    }
                }
            }
        }
    }
}

        stage('Update Kubernetes Images') {
            steps {
                script {
                    // Mettre à jour l'image du backend
                    sh "kubectl set image deployment/backend-deployment backend=${env.DOCKER_HUB_USER}/${env.BACK_IMAGE}:${BUILD_NUMBER}"
                    
                    // Mettre à jour l'image du frontend
                    sh "kubectl set image deployment/frontend-deployment frontend=${env.DOCKER_HUB_USER}/${env.FRONT_IMAGE}:${BUILD_NUMBER}"
                    
                    // Attendre le rollout des mises à jour
                    sh '''
                        kubectl rollout status deployment/backend-deployment --timeout=300s
                        kubectl rollout status deployment/frontend-deployment --timeout=300s
                    '''
                }
            }
        }
    }

    post {
        always {
            // Nettoyage des ressources Docker
            sh 'docker system prune -f --volumes'
            
            // Afficher les logs en cas d'échec
            script {
                if (currentBuild.result == 'FAILURE') {
                    sh '''
                        echo "=== Backend Pods ==="
                        kubectl get pods -l app=backend
                        echo "=== Frontend Pods ==="
                        kubectl get pods -l app=frontend
                        echo "=== MongoDB Pods ==="
                        kubectl get pods -l app=mongodb
                        echo "=== Services ==="
                        kubectl get services
                    '''
                }
            }
        }
        success {
            script {
                // Afficher les URLs d'accès
                sh '''
                    echo "🎉 DÉPLOIEMENT RÉUSSI !"
                    echo "=== URLs de l'application ==="
                    echo "Frontend: $(minikube service frontend-service --url)"
                    echo "Backend: $(minikube service backend-service --url)"
                    echo "=== Commandes utiles ==="
                    echo "Voir tous les pods: kubectl get pods"
                    echo "Voir les services: kubectl get services"
                    echo "Accéder au frontend: minikube service frontend-service"
                '''
                
                // Sauvegarder les URLs dans les variables de build
                frontendUrl = sh(script: 'minikube service frontend-service --url', returnStdout: true).trim()
                backendUrl = sh(script: 'minikube service backend-service --url', returnStdout: true).trim()
                
                echo "Application déployée avec succès!"
                echo "Frontend: ${frontendUrl}"
                echo "Backend: ${backendUrl}"
            }
        }
        failure {
            echo "❌ Le déploiement a échoué. Consultez les logs ci-dessus pour plus de détails."
        }
        cleanup {
            // Nettoyage final
            sh '''
                docker logout
                echo "Cleanup completed"
            '''
        }
    }
}
