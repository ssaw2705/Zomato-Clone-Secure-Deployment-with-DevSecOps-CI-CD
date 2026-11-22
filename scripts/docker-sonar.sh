#!/bin/bash
# Cài Docker + chạy SonarQube container
set -e
sudo apt-get update -y
sudo apt-get install docker.io -y
sudo usermod -aG docker ubuntu
sudo usermod -aG docker jenkins || true
sudo chmod 666 /var/run/docker.sock
sudo systemctl restart jenkins || true

# SonarQube (Elasticsearch) cần giá trị này
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-sonarqube.conf > /dev/null

# Nếu tag lts-community không còn, đổi thành sonarqube:community
docker run -d --name sonar --restart unless-stopped -p 9000:9000 sonarqube:lts-community
echo "SonarQube: http://<PUBLIC_IP>:9000 (admin/admin)"
