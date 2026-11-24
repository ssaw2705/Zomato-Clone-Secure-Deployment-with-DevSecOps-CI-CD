output "instance_id" {
  description = "ID của EC2 (dùng cho aws ec2 stop-instances / start-instances)"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP của EC2 (thay đổi sau mỗi lần Stop/Start)"
  value       = aws_instance.this.public_ip
}

output "ssh_command" {
  description = "Lệnh SSH vào máy"
  value       = local.generate_key ? "ssh -i ${var.project_name}-key.pem ubuntu@${aws_instance.this.public_ip}" : "ssh ubuntu@${aws_instance.this.public_ip}"
}

output "urls" {
  description = "Địa chỉ các dịch vụ"
  value = {
    jenkins       = "http://${aws_instance.this.public_ip}:8080"
    sonarqube     = "http://${aws_instance.this.public_ip}:9000"
    app           = "http://${aws_instance.this.public_ip}:3000"
    prometheus    = "http://${aws_instance.this.public_ip}:9090"
    grafana       = "http://${aws_instance.this.public_ip}:3001"
    node_exporter = "http://${aws_instance.this.public_ip}:9100/metrics"
  }
}
