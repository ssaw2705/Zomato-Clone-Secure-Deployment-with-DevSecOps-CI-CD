pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node16'
    }

    environment {
        SCANNER_HOME   = tool 'sonar-scanner'
        // TODO: đổi thành username Docker Hub của nhóm
        DOCKERHUB_USER = 'your-dockerhub-user'
        IMAGE          = "${DOCKERHUB_USER}/zomato"
    }

    stages {
        stage('Clean workspace') {
            steps { cleanWs() }
        }

        stage('Checkout from Git') {
            steps { checkout scm }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh '$SCANNER_HOME/bin/sonar-scanner'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }

        stage('Install Dependencies') {
            steps { sh 'npm install' }
        }

        stage('OWASP FS Scan') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        stage('Trivy FS Scan') {
            steps { sh 'trivy fs . > trivyfs.txt' }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker', toolName: 'docker') {
                        sh "docker build -t ${IMAGE}:${BUILD_NUMBER} -t ${IMAGE}:latest ."
                        sh "docker push ${IMAGE}:${BUILD_NUMBER}"
                        sh "docker push ${IMAGE}:latest"
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps { sh "trivy image ${IMAGE}:latest > trivy.txt" }
        }

        stage('Deploy to container') {
            steps {
                sh 'docker rm -f zomato || true'
                sh "docker run -d --name zomato -p 3000:3000 ${IMAGE}:latest"
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'trivyfs.txt, trivy.txt', allowEmptyArchive: true
        }
    }
}
