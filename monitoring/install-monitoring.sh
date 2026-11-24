#!/bin/bash
# Cài Prometheus + Node Exporter + Grafana (cổng 3001) trên Ubuntu 22.04
#   Prometheus    : http://<IP>:9090
#   Node Exporter : http://<IP>:9100/metrics
#   Grafana       : http://<IP>:3001  (admin/admin, đổi mật khẩu lần đầu)
# Chạy: sudo bash monitoring/install-monitoring.sh   (chạy lại nhiều lần vẫn an toàn)
set -euo pipefail

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-2.53.2}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
DASHBOARD_IDS="${DASHBOARD_IDS:-1860 9964}"   # Node Exporter Full, Jenkins

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

case "$(uname -m)" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "Kiến trúc không hỗ trợ: $(uname -m)"; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y wget curl tar apt-transport-https software-properties-common gnupg

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

create_user() {
  id "$1" &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin "$1"
}

# ---------------------------------------------------------------------------
# 1. Node Exporter
# ---------------------------------------------------------------------------
echo ">>> Cài Node Exporter v${NODE_EXPORTER_VERSION}"
create_user node_exporter
NE="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}"
wget -q -O "$TMP/ne.tar.gz" \
  "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NE}.tar.gz"
tar -xzf "$TMP/ne.tar.gz" -C "$TMP"
install -m 0755 "$TMP/$NE/node_exporter" /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100 --collector.systemd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ---------------------------------------------------------------------------
# 2. Prometheus
# ---------------------------------------------------------------------------
echo ">>> Cài Prometheus v${PROMETHEUS_VERSION}"
create_user prometheus
PR="prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}"
wget -q -O "$TMP/prom.tar.gz" \
  "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${PR}.tar.gz"
tar -xzf "$TMP/prom.tar.gz" -C "$TMP"
install -m 0755 "$TMP/$PR/prometheus" "$TMP/$PR/promtool" /usr/local/bin/
mkdir -p /etc/prometheus /var/lib/prometheus
for d in consoles console_libraries; do   # Prometheus 3.x không còn 2 thư mục này
  if [ -d "$TMP/$PR/$d" ]; then cp -r "$TMP/$PR/$d" /etc/prometheus/; fi
done
install -m 0644 "$SCRIPT_DIR/prometheus.yml" /etc/prometheus/prometheus.yml
promtool check config /etc/prometheus/prometheus.yml
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --web.listen-address=:9090 \
  --web.enable-lifecycle
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter prometheus
systemctl restart node_exporter prometheus

# ---------------------------------------------------------------------------
# 3. Grafana (cổng 3001 để không trùng app React ở 3000)
# ---------------------------------------------------------------------------
echo ">>> Cài Grafana (cổng ${GRAFANA_PORT})"
mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list
apt-get update -y
apt-get install -y grafana

# Đổi cổng HTTP trong grafana.ini (dòng mặc định là ";http_port = 3000")
sed -i -E "s/^;?http_port = .*/http_port = ${GRAFANA_PORT}/" /etc/grafana/grafana.ini

# Provisioning: datasource Prometheus + thư mục dashboard
install -m 0644 "$SCRIPT_DIR/grafana/provisioning/datasources/prometheus.yml" \
  /etc/grafana/provisioning/datasources/prometheus.yml
install -m 0644 "$SCRIPT_DIR/grafana/provisioning/dashboards/dashboards.yml" \
  /etc/grafana/provisioning/dashboards/zomato.yml

# Tải dashboard từ grafana.com, gán datasource uid "prometheus"
mkdir -p /var/lib/grafana/dashboards
for id in $DASHBOARD_IDS; do
  if curl -fsSL "https://grafana.com/api/dashboards/${id}/revisions/latest/download" -o "$TMP/${id}.json"; then
    sed -E 's/\$\{DS_[A-Za-z0-9_]+\}/prometheus/g' "$TMP/${id}.json" > "/var/lib/grafana/dashboards/${id}.json"
    echo "    + dashboard ${id}"
  else
    echo "    ! không tải được dashboard ${id} – import thủ công trong Grafana"
  fi
done
chown -R grafana:grafana /var/lib/grafana/dashboards

systemctl daemon-reload
systemctl enable --now grafana-server
systemctl restart grafana-server

# ---------------------------------------------------------------------------
# 4. Kiểm tra
# ---------------------------------------------------------------------------
sleep 5
for svc in node_exporter prometheus grafana-server; do
  printf '%-16s %s\n' "$svc" "$(systemctl is-active "$svc")"
done
curl -fs -o /dev/null http://localhost:9100/metrics   && echo "Node Exporter OK"
curl -fs -o /dev/null http://localhost:9090/-/ready   && echo "Prometheus OK"
curl -fs -o /dev/null "http://localhost:${GRAFANA_PORT}/api/health" && echo "Grafana OK" \
  || echo "Grafana đang khởi động, thử lại sau ít giây"

IP="$(curl -fs --max-time 3 https://checkip.amazonaws.com || echo '<PUBLIC_IP>')"
echo
echo "Prometheus : http://${IP}:9090/targets"
echo "Grafana    : http://${IP}:${GRAFANA_PORT}  (admin/admin)"
echo "Nhớ cài plugin Jenkins 'Prometheus metrics' để target 'jenkins' chuyển sang UP."
