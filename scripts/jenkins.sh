#!/bin/bash
# Cài Java 17 + 21 (Temurin) + Jenkins trên Ubuntu 22.04
set -e
# Cài key Jenkins TRƯỚC lần apt update đầu tiên: nếu máy đã có jenkins.list với key cũ,
# apt update sẽ lỗi và set -e dừng script.
# Khi Jenkins đổi key: lấy tên file key mới tại https://pkg.jenkins.io/debian-stable/
JENKINS_KEY_URL="https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key"
curl -fsSL "$JENKINS_KEY_URL" | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
sudo apt update -y
sudo mkdir -p /etc/apt/keyrings
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update -y
# Jenkins >= 2.5xx cần Java 21 để chạy; giữ thêm JDK 17 cho các job (tool 'jdk17' trong Jenkinsfile)
sudo apt install temurin-17-jdk temurin-21-jdk -y
java --version

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install jenkins -y
# Ép service Jenkins chạy bằng Java 21
sudo mkdir -p /etc/systemd/system/jenkins.service.d
printf '[Service]\nEnvironment="JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64"\n' | sudo tee /etc/systemd/system/jenkins.service.d/java21.conf > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl restart jenkins
echo "Initial admin password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
