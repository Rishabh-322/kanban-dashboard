pipeline {
    agent any

    environment {
        DOCKER_REPO = 'rishabh322/kanban-dashboard'
        APP_NAME = 'kanban-dashboard'
        APP_PORT = '3000'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm

                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_SHA}"
                    env.IMAGE = "${env.DOCKER_REPO}:${env.IMAGE_TAG}"
                }

                echo "Building ${env.IMAGE}"
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build -t "$IMAGE" .
                '''
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_TOKEN" | \
                        docker login -u "$DOCKER_USER" --password-stdin

                        docker push "$IMAGE"
                    '''
                }
            }
        }

        stage('Registry Pull Test') {
            steps {
                sh '''
                    docker image rm "$IMAGE" || true
                    docker pull "$IMAGE"
                '''
            }
        }

        stage('Deploy') {
            steps {
                script {
                    env.PREVIOUS_IMAGE = sh(
                        script: '''
                            docker inspect \
                            --format='{{.Config.Image}}' \
                            "$APP_NAME" 2>/dev/null || true
                        ''',
                        returnStdout: true
                    ).trim()

                    env.DEPLOY_STARTED = 'true'
                }

                sh '''
                    docker rm -f "$APP_NAME" || true

                    docker run -d \
                        --name "$APP_NAME" \
                        --restart unless-stopped \
                        --memory=256m \
                        --cpus=0.5 \
                        -p "$APP_PORT:$APP_PORT" \
                        "$IMAGE"
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    for i in $(seq 1 12); do

                        STATUS=$(docker inspect \
                            --format='{{.State.Health.Status}}' \
                            "$APP_NAME" 2>/dev/null || echo "starting")

                        echo "Container status: $STATUS"

                        if [ "$STATUS" = "healthy" ]; then

                            curl -fsS \
                                "http://127.0.0.1:3999/health"

                            echo ""
                            echo "Application is healthy."
                            exit 0
                        fi

                        sleep 5
                    done

                    echo "Health check failed."

                    docker logs "$APP_NAME" || true

                    exit 1
                '''
            }
        }
    }

    post {

        success {
            echo "Deployment successful: ${env.IMAGE}"
        }

        failure {
            script {

                if (
                    env.DEPLOY_STARTED == 'true' &&
                    env.PREVIOUS_IMAGE?.trim()
                ) {

                    echo "Rolling back to ${env.PREVIOUS_IMAGE}"

                    sh '''
                        docker rm -f "$APP_NAME" || true

                        docker run -d \
                            --name "$APP_NAME" \
                            --restart unless-stopped \
                            --memory=256m \
                            --cpus=0.5 \
                            -p "$APP_PORT:$APP_PORT" \
                            "$PREVIOUS_IMAGE"
                    '''

                } else {
                    echo "No previous deployment available for rollback."
                }
            }
        }

        always {
            sh '''
                docker logout || true
            '''
        }
    }
}