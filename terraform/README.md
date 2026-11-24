# 🏗 Terraform – Hạ tầng AWS (TV1)

Tạo **1 EC2 Ubuntu 22.04 (`t2.large`, 30GB gp3)** trong VPC mặc định, kèm Security Group, Key pair và `user_data` tự cài toàn bộ công cụ của đồ án.

## Tài nguyên được tạo

| Tài nguyên | Mô tả |
|---|---|
| `aws_instance.this` | EC2 Ubuntu 22.04, ổ 30GB mã hoá, bắt buộc IMDSv2 |
| `aws_security_group.this` | Mở `22` (SSH), `8080` Jenkins, `9000` SonarQube, `3000` App, `9090` Prometheus, `3001` Grafana, `9100` Node Exporter |
| `aws_key_pair.this` | Dùng public key có sẵn, hoặc tự sinh → lưu `zomato-devsecops-key.pem` |
| `aws_budgets_budget.monthly` | (tuỳ chọn) gửi email khi chi phí vượt ngưỡng |

`user_data` (`user_data.sh.tftpl`) clone repo nhóm về `/opt/zomato-devsecops` rồi lần lượt chạy:

1. `scripts/jenkins.sh` – Java 17 + Jenkins
2. `scripts/docker-sonar.sh` – Docker + SonarQube container
3. `scripts/trivy.sh` – Trivy
4. `monitoring/install-monitoring.sh` – Prometheus + Node Exporter + Grafana

Một bước lỗi không làm dừng các bước sau. Log: `/var/log/user-data.log`.

## Yêu cầu

- Terraform ≥ 1.5, AWS CLI
- IAM user có quyền EC2 (và Budgets nếu dùng cảnh báo chi phí)

```bash
aws configure          # nhập Access Key, Secret Key, region ap-southeast-1
```

## Cách dùng

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # sửa ssh_cidr, budget_email...
terraform init
terraform fmt -check && terraform validate
terraform plan
terraform apply                                 # gõ yes
terraform output                                # in Public IP, lệnh SSH, URL các dịch vụ
```

Cài đặt mất khoảng **10–15 phút** sau khi `apply` xong. Kiểm tra:

```bash
ssh -i zomato-devsecops-key.pem ubuntu@<PUBLIC_IP>
sudo tail -f /var/log/user-data.log            # chờ dòng "user_data hoàn tất"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

> Trên Windows, nếu SSH báo *bad permissions* với file `.pem`:
> `icacls zomato-devsecops-key.pem /inheritance:r /grant:r "%USERNAME%:R"`

## Quản lý chi phí 💰

`t2.large` ≈ **0,09 USD/giờ** (~2 USD/ngày nếu chạy liên tục) + ổ 30GB.

| Khi nào | Lệnh |
|---|---|
| Cuối mỗi buổi làm việc | `aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)` |
| Bắt đầu buổi mới | `aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)` rồi `terraform refresh && terraform output public_ip` (IP đổi sau mỗi lần Start) |
| Kết thúc đồ án | `terraform destroy` |

Đặt `budget_email` trong `terraform.tfvars` để nhận email khi chi phí tháng vượt 80% ngưỡng `budget_limit_usd`.

## Bảo mật

- **Không commit** `terraform.tfstate`, `*.tfvars`, `*.pem` (đã có trong `.gitignore`). State chứa private key khi dùng chế độ tự sinh key.
- Nên đặt `ssh_cidr = "<IP-của-bạn>/32"` thay vì `0.0.0.0/0`.
- Chỉ 1 người (TV1) giữ state và chạy `apply`/`destroy`, tránh tạo trùng tài nguyên.
