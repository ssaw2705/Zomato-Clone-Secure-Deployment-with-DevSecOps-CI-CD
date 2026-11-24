# 📈 Giám sát – Prometheus + Node Exporter + Grafana (TV1)

```
Node Exporter :9100 ──┐
Jenkins :8080/prometheus ──► Prometheus :9090 ──► Grafana :3001
Prometheus :9090 ─────┘        (scrape 15s, lưu 15 ngày)
```

| Thành phần | Cổng | Cài bằng |
|---|---|---|
| Node Exporter | `9100` | binary + systemd `node_exporter` |
| Prometheus | `9090` | binary + systemd `prometheus` |
| Grafana | `3001` (tránh trùng app ở `3000`) | apt + systemd `grafana-server` |

## Cấu trúc

| File | Mô tả |
|---|---|
| `prometheus.yml` | 3 job: `prometheus`, `node_exporter`, `jenkins` |
| `install-monitoring.sh` | Cài cả 3 thành phần, copy cấu hình, tự import dashboard |
| `grafana/provisioning/datasources/prometheus.yml` | Datasource Prometheus mặc định (uid `prometheus`) |
| `grafana/provisioning/dashboards/dashboards.yml` | Nạp dashboard từ `/var/lib/grafana/dashboards` vào folder *DevSecOps* |

## 1. Cài đặt

Nếu EC2 tạo bằng Terraform (`terraform/`), script này **đã tự chạy** trong `user_data`. Cài tay:

```bash
cd /opt/zomato-devsecops        # hoặc thư mục clone repo
sudo bash monitoring/install-monitoring.sh
```

Đổi phiên bản: `sudo PROMETHEUS_VERSION=2.53.2 NODE_EXPORTER_VERSION=1.8.2 bash monitoring/install-monitoring.sh`

## 2. Thu thập metrics Jenkins

1. Jenkins → *Manage Jenkins → Plugins → Available* → cài **Prometheus metrics** → restart Jenkins.
2. (Tuỳ chọn) *Manage Jenkins → System → Prometheus*: giữ path `prometheus`, bỏ chọn *Enable authentication for prometheus end-point* (mặc định đã tắt).
3. Kiểm tra: `curl -s http://localhost:8080/prometheus/ | head`
4. Mở `http://<IP>:9090/targets` → cả 3 target `prometheus`, `node_exporter`, `jenkins` phải **UP**.

Sau khi sửa `prometheus.yml`:

```bash
sudo cp monitoring/prometheus.yml /etc/prometheus/prometheus.yml
promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload
```

## 3. Grafana

1. Mở `http://<IP>:3001` → đăng nhập `admin/admin` → đổi mật khẩu.
2. Datasource **Prometheus** đã được tạo sẵn (*Connections → Data sources*).
3. Dashboard đã được import sẵn vào folder **DevSecOps**. Nếu thiếu, import thủ công: *Dashboards → New → Import* → nhập ID → chọn datasource *Prometheus*:

| Dashboard | ID |
|---|---|
| Node Exporter Full | `1860` |
| Jenkins: Performance and Health Overview | `9964` |

## 4. Truy vấn PromQL mẫu (dùng khi demo)

| Ý nghĩa | PromQL |
|---|---|
| CPU sử dụng (%) | `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100` |
| RAM sử dụng (%) | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` |
| Ổ đĩa `/` sử dụng (%) | `(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100` |
| Số build Jenkins thành công | `default_jenkins_builds_success_build_count_total` |
| Số build thất bại | `default_jenkins_builds_failed_build_count_total` |
| Executor đang bận | `jenkins_executor_in_use_value` |

> Tên metric Jenkins có thể khác chút tuỳ phiên bản plugin – kiểm tra bằng
> `curl -s http://localhost:8080/prometheus/ | grep -E "builds_(success|failed)|executor"`.
>
> Gợi ý demo: chạy pipeline Jenkins rồi xem CPU/RAM trên dashboard 1860 tăng trong lúc build Docker và quét OWASP.

## 5. Ảnh chụp cần nộp

Lưu vào `docs/images/monitoring/`:

- [ ] `prometheus-targets.png` – trang `/targets`, 3 target UP
- [ ] `grafana-node-exporter.png` – dashboard Node Exporter Full (1860)
- [ ] `grafana-jenkins.png` – dashboard Jenkins (9964) sau vài lần build
- [ ] `terraform-apply.png` – kết quả `terraform apply` / `terraform output`
- [ ] `ec2-console.png` – EC2 + Security Group trên AWS Console

## Xử lý lỗi

| Hiện tượng | Cách xử lý |
|---|---|
| Target `jenkins` DOWN, lỗi 404 | Chưa cài plugin Prometheus metrics hoặc Jenkins chưa restart |
| Target `jenkins` DOWN, lỗi 403 | Bật *Enable authentication* trong plugin → tắt đi |
| Không vào được `:3001` / `:9090` | Kiểm tra Security Group, `sudo systemctl status grafana-server prometheus` |
| Dashboard trống "No data" | Chọn đúng datasource *Prometheus*, chỉnh time range *Last 15 minutes* |
| Log | `journalctl -u prometheus -f`, `journalctl -u grafana-server -f` |
