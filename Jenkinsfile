pipeline {
    agent any

    tools {
        jdk 'JDK17'
        maven 'Maven'
    }

    options {
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(
            name: 'PUSH_DOCKER_HUB',
            defaultValue: false,
            description: 'Opcional: publicar a imagem no Docker Hub após o build local.'
        )
    }

    environment {
        PATH = "/opt/homebrew/bin:/usr/local/bin:/Applications/Docker.app/Contents/Resources/bin:${env.PATH}"
        DOCKER_IMAGE = 'andprof/jogo-enigma-api'
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        IMAGE_TAG = "${BUILD_NUMBER}"
        COMPOSE_FILE = 'docker-compose.homol.yml'
    }

    stages {
        stage('1 - Checkout') {
            steps {
                checkout scm
            }
        }

        stage('2 - CI - Testes JUnit + JaCoCo') {
            steps {
                sh 'mvn -B clean test'
            }
            post {
                always {
                    junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: false
                    archiveArtifacts artifacts: 'target/site/jacoco/**', allowEmptyArchive: true
                }
            }
        }

        stage('3 - CI - Qualidade PMD') {
            steps {
                sh 'mvn -B pmd:pmd -DskipTests'
            }
            post {
                always {
                    archiveArtifacts artifacts: 'target/site/pmd.html,target/reports/pmd.html,target/pmd.xml', allowEmptyArchive: true
                }
            }
        }

        stage('4 - CI - Package') {
            steps {
                sh 'mvn -B package -DskipTests'
            }
        }

        stage('5 - CD - Build dos Containers') {
            steps {
                sh 'docker compose -f "$COMPOSE_FILE" build api bff'
            }
        }

        stage('6 - Registry - Docker Hub (opcional)') {
            when {
                expression { return params.PUSH_DOCKER_HUB }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: env.DOCKER_CREDENTIALS_ID,
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh '''
                        set +x
                        printf '%s' "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin
                        trap 'docker logout' EXIT
                        docker push "$DOCKER_IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('7 - CD - Deploy HOMOL') {
            steps {
                sh '''
                    docker compose -f "$COMPOSE_FILE" down --remove-orphans
                    docker compose -f "$COMPOSE_FILE" up -d
                '''
            }
        }

        stage('8 - CD - Health Check HOMOL') {
            steps {
                sh '''
                    for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
                        if curl -fsS --max-time 5 http://localhost:8080/actuator/health | grep -Eq '"status"[[:space:]]*:[[:space:]]*"UP"'; then
                            echo "API pronta: UP"
                            exit 0
                        fi
                        echo "API ainda nao pronta. Tentativa $i/12..."
                        sleep 5
                    done
                    echo "Health check da API falhou."
                    exit 1
                '''
            }
        }

        stage('9 - CD - Cypress E2E') {
            steps {
                dir('frontend') {
                    sh '''
                        npm install
                        CYPRESS_BASE_URL=http://localhost:3000 npm run test:e2e
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'frontend/cypress/screenshots/**,frontend/cypress/videos/**', allowEmptyArchive: true
                }
            }
        }

        stage('10 - Observabilidade') {
            steps {
                echo 'API: http://localhost:8080'
                echo 'BFF/Front: http://localhost:3000'
                echo 'Prometheus: http://localhost:9091'
                echo 'Grafana: http://localhost:3001'
            }
        }
    }

    post {
        success {
            echo 'Pipeline CI/CD concluido: build, testes, container, deploy HOMOL e E2E aprovados.'
        }
        failure {
            echo 'Pipeline interrompido. Identifique no Stage View o ponto de falha e consulte o Console Output.'
        }
        always {
            archiveArtifacts artifacts: 'target/site/jacoco/**,target/site/pmd.html,target/reports/pmd.html,target/pmd.xml,frontend/cypress/screenshots/**,frontend/cypress/videos/**', allowEmptyArchive: true
        }
    }
}
