# 📋 Phân công công việc – Zomato Clone DevSecOps CI/CD

> Repo: https://github.com/ssaw2705/Zomato-Clone-Secure-Deployment-with-DevSecOps-CI-CD
> Nguyên tắc: mỗi thành viên phụ trách **một mảng công nghệ**, làm trên nhánh riêng, merge vào `master` qua **Pull Request** (ít nhất 1 người review).

## 1. Tổng quan

| Thành viên | Họ tên | Vai trò | Công nghệ phụ trách |
|---|---|---|---|
| **TV1** | | Hạ tầng & Giám sát | AWS EC2, Terraform, Prometheus, Grafana |
| **TV2** | | CI/CD | Jenkins, Git/GitHub |
| **TV3** | | Bảo mật (DevSecOps) | SonarQube, OWASP Dependency-Check, Trivy |
| **TV4** | | Container & Triển khai | Docker, Docker Hub, Kubernetes |

---

## 2. Chi tiết nhiệm vụ

### 👤 TV1 – Hạ tầng (Terraform + AWS) & Giám sát (Prometheus + Grafana)

**Nhiệm vụ**
- [ ] Viết Terraform tạo hạ tầng AWS:
  - EC2 Ubuntu 22.04, `t2.large`, ổ 30GB
  - Security Group: `22`, `8080` (Jenkins), `9000` (SonarQube), `3000` (App), `9090` (Prometheus), `3001` (Grafana), `9100` (Node Exporter)
  - Key pair, `user_data` gọi các script trong `scripts/` để tự cài công cụ
  - `outputs.tf` in ra Public IP
- [ ] Cài Prometheus + Node Exporter + Grafana (Grafana chạy cổng `3001` để không trùng app)
- [ ] Thu thập metrics EC2 (Node Exporter) và Jenkins (plugin *Prometheus metrics*)
- [ ] Import dashboard Grafana: Node Exporter Full (ID `1860`), Jenkins (ID `9964`)
- [ ] Quản lý chi phí: Stop/Terminate EC2 cuối ngày, `terraform destroy` khi kết thúc

**Sản phẩm bàn giao**
- `terraform/` – `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- `monitoring/` – `prometheus.yml`, script cài đặt
- Ảnh chụp dashboard Grafana

**Nhánh:** `feature/terraform`, `feature/monitoring`

---

### 👤 TV2 – CI/CD (Jenkins + GitHub)

**Nhiệm vụ**
- [ ] Cài Jenkins (`scripts/jenkins.sh`), tạo tài khoản cho từng thành viên
- [ ] Cài plugin: Eclipse Temurin Installer, SonarQube Scanner, NodeJS, OWASP Dependency-Check, Docker, Docker Commons, Docker Pipeline, Docker API, docker-build-step
- [ ] Cấu hình Tools: `jdk17`, `node16`, `sonar-scanner`, `DP-Check`, `docker`
- [ ] Cấu hình Credentials: `Sonar-token` (Secret text), `docker` (Docker Hub), GitHub token (nếu repo private)
- [ ] Tạo job **Pipeline script from SCM** → repo nhóm, branch `*/master`, `Jenkinsfile`
- [ ] Tạo GitHub webhook `http://<IP>:8080/github-webhook/` → tự build khi merge
- [ ] Quản lý ruleset nhánh `master`, hướng dẫn nhóm quy trình nhánh/PR
- [ ] Thêm `post` vào Jenkinsfile: thông báo build thành công/thất bại (Email/Slack/Discord)

**Sản phẩm bàn giao**
- `Jenkinsfile` hoàn chỉnh
- Ảnh chụp Stage View, cấu hình job, webhook
- Sơ đồ luồng CI/CD

**Nhánh:** `feature/jenkins-pipeline`

---

### 👤 TV3 – Bảo mật (SonarQube + OWASP + Trivy)

**Nhiệm vụ**
- [ ] Chạy SonarQube (`scripts/docker-sonar.sh`), tạo token, webhook về Jenkins
- [ ] Tạo **Quality Gate** riêng cho nhóm (vd: 0 lỗi Critical/Blocker), chỉnh `sonar-project.properties`
- [ ] Cấu hình OWASP Dependency-Check (đăng ký **NVD API key** để quét nhanh hơn)
- [ ] Cài Trivy (`scripts/trivy.sh`), chỉnh lệnh quét: `--severity HIGH,CRITICAL`, xuất báo cáo HTML/JSON
- [ ] Phân tích kết quả: liệt kê CVE, đánh giá mức độ, đề xuất cách khắc phục
- [ ] Thực hiện sửa một số lỗ hổng (nâng phiên bản thư viện, đổi base image) → so sánh **trước/sau**

**Sản phẩm bàn giao**
- `sonar-project.properties`, các stage quét trong `Jenkinsfile`
- `docs/security-report.md` – bảng CVE, mức độ, cách khắc phục, kết quả trước/sau
- Ảnh chụp SonarQube dashboard, báo cáo OWASP, Trivy

**Nhánh:** `feature/security-scan`

---

### 👤 TV4 – Container (Docker) & Kubernetes

**Nhiệm vụ**
- [ ] Tối ưu `Dockerfile`: multi-stage, chạy bằng user non-root, `HEALTHCHECK`, giảm kích thước image
- [ ] Quản lý image trên Docker Hub, tag theo `BUILD_NUMBER` và `latest`
- [ ] Viết manifest Kubernetes:
  - `namespace.yaml`
  - `deployment.yaml` (2 replicas, resource limits, liveness/readiness probe)
  - `service.yaml` (NodePort)
- [ ] Dựng cluster: **k3s** trên EC2 thứ 2 hoặc **minikube** trên máy local (tiết kiệm chi phí)
- [ ] Phối hợp TV2 thêm stage `Deploy to Kubernetes` (`kubectl apply -f k8s/`)

**Sản phẩm bàn giao**
- `Dockerfile` tối ưu, `.dockerignore`
- `k8s/` – các file manifest + `README.md` hướng dẫn chạy
- Demo app chạy trên Kubernetes (ảnh chụp `kubectl get pods,svc`)

**Nhánh:** `feature/docker`, `feature/k8s`

---

## 3. Tiến độ

| Tuần | TV1 | TV2 | TV3 | TV4 |
|---|---|---|---|---|
| **1** | Terraform tạo EC2 | Cài Jenkins, plugin, tools | Cài SonarQube, Trivy | Tối ưu Dockerfile (local) |
| **2** | Hoàn thiện `user_data`, outputs | Pipeline cơ bản chạy được, webhook | Gắn stage quét, Quality Gate | Viết manifest K8s, dựng cluster |
| **3** | Prometheus + Grafana | Stage deploy K8s (cùng TV4), thông báo | Phân tích & sửa lỗ hổng | Deploy K8s qua pipeline |
| **4** | Cả nhóm: chạy toàn bộ luồng end-to-end, viết báo cáo, làm slide, tập demo | | | |

**Phụ thuộc chính**
- TV2, TV3 cần EC2 của **TV1** (tuần 1 có thể dùng EC2 tạo tay nếu Terraform chưa xong).
- TV3 cần pipeline cơ bản của **TV2** để gắn stage quét.
- Stage deploy K8s cần cả **TV2** và **TV4**.

---

## 4. Quy trình làm việc chung

1. Cập nhật code mới nhất:
   ```bash
   git checkout master && git pull
   ```
2. Tạo nhánh theo phần việc:
   ```bash
   git checkout -b feature/<ten-viec>
   ```
3. Commit nhỏ, message rõ ràng, sau đó push:
   ```bash
   git push -u origin feature/<ten-viec>
   ```
4. Mở **Pull Request** vào `master`, gán 1 người review.
5. Merge xong → Jenkins tự chạy pipeline (webhook). Pipeline đỏ thì người merge chịu trách nhiệm sửa.

**Quy ước**
- Không commit mật khẩu, token, file `.pem`, `terraform.tfstate` lên repo.
- Mỗi người review ít nhất 1 PR của thành viên khác.
- Họp nhanh 15 phút mỗi tuần: đã làm gì, sẽ làm gì, đang vướng gì.

---

## 5. Báo cáo & thuyết trình

| Chương | Người viết |
|---|---|
| Giới thiệu, kiến trúc tổng thể | Cả nhóm |
| Hạ tầng Terraform & giám sát | TV1 |
| Pipeline CI/CD | TV2 |
| Bảo mật & phân tích lỗ hổng | TV3 |
| Container & Kubernetes | TV4 |
| Kết luận, hướng phát triển | Cả nhóm |

Mỗi người chuẩn bị **2–3 slide** cho phần của mình và demo trực tiếp phần đó.
