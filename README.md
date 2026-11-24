# 🍽 Zomato Clone – DevSecOps CI/CD (Đồ án nhóm)

Triển khai ứng dụng React "Zomato Clone" bằng pipeline DevSecOps trên **1 máy AWS EC2**:

```
GitHub ──► Jenkins ──► SonarQube (chất lượng code + Quality Gate)
                   ──► npm install
                   ──► OWASP Dependency-Check + Trivy FS (quét thư viện / mã nguồn)
                   ──► Docker build & push lên Docker Hub
                   ──► Trivy image scan
                   ──► docker run → http://<EC2_IP>:3000
```

Nguồn app: [NotHarshhaa/Zomato-Clone](https://github.com/NotHarshhaa/Zomato-Clone) · Hướng dẫn gốc: [blog ProDevOpsGuy](https://blog.prodevopsguytech.com/zomato-clone-secure-deployment-with-devsecops-cicd)

## Cấu trúc repo

| Đường dẫn | Mô tả |
|---|---|
| `src/`, `public/` | Mã nguồn React |
| `Dockerfile` | Build bằng Node 16, chạy bản build tĩnh bằng `serve` ở cổng 3000 |
| `Jenkinsfile` | Pipeline DevSecOps (Jenkins đọc từ repo) |
| `sonar-project.properties` | Cấu hình SonarQube Scanner |
| `scripts/` | Script cài Jenkins, Docker + SonarQube, Trivy trên EC2 |
| `docs/APP_README.md` | README gốc của app |

## Chạy app ở máy local

```bash
npm install
npm start            # http://localhost:3000  (dùng Node 16)
# hoặc bằng Docker
docker build -t zomato . && docker run -d -p 3000:3000 zomato
```

## Triển khai hạ tầng (1 người làm, cả nhóm dùng chung)

### 1. EC2
- Ubuntu 22.04, **t2.large**, ổ 30GB.
- Security Group inbound: `22`, `8080` (Jenkins), `9000` (SonarQube), `3000` (app).

### 2. Cài công cụ
```bash
git clone <URL_REPO_NHÓM> && cd zomato-devsecops/scripts
chmod +x *.sh
./jenkins.sh        # in ra mật khẩu admin Jenkins
./docker-sonar.sh
./trivy.sh
```
Mở `http://<IP>:8080` → Install suggested plugins → tạo user admin (tạo thêm user cho từng thành viên trong *Manage Jenkins → Users*).

### 3. Plugin Jenkins
*Manage Jenkins → Plugins*: Eclipse Temurin Installer, SonarQube Scanner, NodeJS, OWASP Dependency-Check, Docker, Docker Commons, Docker Pipeline, Docker API, docker-build-step.

### 4. Tools (tên phải đúng)

| Loại | Tên | Cấu hình |
|---|---|---|
| JDK | `jdk17` | Install from adoptium.net – jdk-17 |
| NodeJS | `node16` | NodeJS 16.x |
| SonarQube Scanner | `sonar-scanner` | latest |
| Dependency-Check | `DP-Check` | Install from github.com |
| Docker | `docker` | latest |

### 5. SonarQube + Credentials
1. SonarQube (`admin/admin`, đổi mật khẩu) → *My Account → Security* → tạo token.
2. Jenkins *Credentials → Global*:
   - **Secret text**, ID `Sonar-token` = token SonarQube
   - **Username with password**, ID `docker` = tài khoản Docker Hub
3. *Manage Jenkins → System → SonarQube servers*: Name `sonar-server`, URL `http://<IP>:9000`, token `Sonar-token`.
4. SonarQube *Administration → Configuration → Webhooks*: `http://<IP>:8080/sonarqube-webhook/`

### 6. Tạo job
- Sửa `DOCKERHUB_USER` trong `Jenkinsfile` → commit.
- Jenkins → *New Item* → `zomato` → **Pipeline** → *Definition: Pipeline script from SCM* → Git → URL repo nhóm, branch `*/master`, Script Path `Jenkinsfile`.
  (Repo private: thêm credential GitHub username + Personal Access Token.)
- *Build Now*. Lần đầu OWASP tải NVD mất 10–30 phút.

### 7. Kiểm tra
- App: `http://<IP>:3000`
- SonarQube: project `zomato`
- Báo cáo Trivy: Artifacts của mỗi build (`trivyfs.txt`, `trivy.txt`)

> ⚠️ Xong việc nhớ **Stop/Terminate EC2** để không bị tính phí.

## Quy trình làm việc nhóm

1. Không commit thẳng vào `master`. Tạo nhánh: `git checkout -b feature/<ten-viec>`
2. Commit nhỏ, rõ ràng → `git push -u origin feature/<ten-viec>`
3. Mở **Pull Request** vào `master`, ít nhất 1 người review.
4. Merge xong → chạy lại job Jenkins (hoặc cấu hình GitHub webhook `http://<IP>:8080/github-webhook/` để tự chạy).

## Phân công gợi ý

| Hạng mục | Người phụ trách |
|---|---|
| EC2 + cài Jenkins/Docker/SonarQube/Trivy | |
| Cấu hình Jenkins (plugin, tools, credentials) | |
| Pipeline + Dockerfile | Thanh Duy |
| Báo cáo bảo mật (Sonar, OWASP, Trivy) + slide | |
| Mở rộng: Kubernetes / Terraform / Prometheus + Grafana | |

## Lỗi thường gặp
- **Quality Gate treo**: sai URL webhook hoặc chưa mở cổng 8080.
- **permission denied /var/run/docker.sock**: `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins`.
- **SonarQube tự tắt**: thiếu RAM hoặc thiếu `vm.max_map_count=262144`.
- **ERR_OSSL_EVP_UNSUPPORTED**: đang dùng Node ≥17; dùng Node 16.
