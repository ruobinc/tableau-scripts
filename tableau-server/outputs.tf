#############################################
# Tableau Server on AWS - 出力定義
#############################################

output "instance_id" {
  description = "EC2インスタンスID"
  value       = aws_instance.tableau_server.id
}

output "public_ip" {
  description = "パブリックIPアドレス（Elastic IP）"
  value       = aws_eip.tableau_server.public_ip
}

output "public_dns" {
  description = "パブリックDNS名"
  value       = aws_eip.tableau_server.public_dns
}

output "private_ip" {
  description = "プライベートIPアドレス"
  value       = aws_instance.tableau_server.private_ip
}

output "http_url" {
  description = "Tableau Server HTTP URL"
  value       = "http://${aws_eip.tableau_server.public_ip}:8080"
}

output "https_url" {
  description = "Tableau Server HTTPS URL"
  value       = var.enable_https ? "https://${aws_eip.tableau_server.public_ip}" : "HTTPS is disabled"
}

output "ssh_command" {
  description = "SSH接続コマンド"
  value       = "ssh -i <your-key.pem> ec2-user@${aws_eip.tableau_server.public_ip}"
}

output "setup_log_command" {
  description = "セットアップログ確認コマンド"
  value       = "ssh -i <your-key.pem> ec2-user@${aws_eip.tableau_server.public_ip} 'tail -f /var/log/tableau-setup.log'"
}

output "security_group_id" {
  description = "セキュリティグループID"
  value       = aws_security_group.tableau_server.id
}

output "data_volume_id" {
  description = "データボリュームID"
  value       = var.data_volume_size > 0 ? aws_ebs_volume.tableau_data[0].id : null
}

output "admin_username" {
  description = "Tableau Server管理者ユーザー名"
  value       = var.admin_username
}

output "important_notes" {
  description = "重要な注意事項"
  value       = <<-EOT

    ===== Tableau Server セットアップ情報 =====

    1. セットアップ完了まで40-50分かかります
    2. ログ確認: ${aws_eip.tableau_server.public_ip}にSSH接続後、以下を実行
       tail -f /var/log/tableau-setup.log

    3. セットアップ完了後のアクセス:
       - HTTP:  http://${aws_eip.tableau_server.public_ip}:8080
       ${var.enable_https ? "- HTTPS: https://${aws_eip.tableau_server.public_ip}" : ""}

    4. 初回ログイン:
       - ユーザー名: ${var.admin_username}
       - パスワード: terraform.tfvarsで設定した値

    5. TSMステータス確認:
       docker exec tableau-server tsm status -v

    ==========================================
  EOT
}
