variable "aws_region" {
  description = "AWS region tạo hạ tầng (Singapore gần Việt Nam nhất)"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tiền tố đặt tên cho tài nguyên"
  type        = string
  default     = "zomato-devsecops"
}

variable "instance_type" {
  description = "Loại EC2 (Jenkins + SonarQube + Docker cần >= 8GB RAM)"
  type        = string
  default     = "t2.large"
}

variable "root_volume_size" {
  description = "Dung lượng ổ root (GB)"
  type        = number
  default     = 30
}

variable "ssh_cidr" {
  description = "Dải IP được phép SSH (nên đặt IP của bạn, vd 1.2.3.4/32)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_cidr" {
  description = "Dải IP được phép truy cập các cổng web (Jenkins, SonarQube, App, Prometheus, Grafana...)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_ports" {
  description = "Các cổng TCP mở ra ngoài (ngoài cổng 22)"
  type        = map(number)
  default = {
    jenkins       = 8080
    sonarqube     = 9000
    app           = 3000
    prometheus    = 9090
    grafana       = 3001
    node_exporter = 9100
  }
}

variable "public_key_path" {
  description = "Đường dẫn public key SSH có sẵn. Để trống => Terraform tự sinh key và lưu file .pem trong thư mục terraform/"
  type        = string
  default     = ""
}

variable "repo_url" {
  description = "Repo GitHub của nhóm (user_data sẽ clone về để chạy scripts/)"
  type        = string
  default     = "https://github.com/ssaw2705/Zomato-Clone-Secure-Deployment-with-DevSecOps-CI-CD.git"
}

variable "repo_branch" {
  description = "Nhánh dùng để lấy các script cài đặt"
  type        = string
  default     = "master"
}

variable "install_tools" {
  description = "true => user_data tự cài Jenkins, Docker + SonarQube, Trivy, Prometheus, Grafana"
  type        = bool
  default     = true
}

variable "budget_email" {
  description = "Email nhận cảnh báo chi phí AWS Budgets. Để trống => không tạo budget"
  type        = string
  default     = ""
}

variable "budget_limit_usd" {
  description = "Ngưỡng chi phí hàng tháng (USD) để gửi cảnh báo"
  type        = number
  default     = 20
}
