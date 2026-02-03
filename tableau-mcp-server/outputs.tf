#############################################
# Tableau MCP Server on AWS - 出力値定義
#############################################

output "instance_id" {
  description = "EC2インスタンスID"
  value       = aws_instance.mcp_server.id
}

output "public_ip" {
  description = "Elastic IP（固定IP）"
  value       = aws_eip.mcp_server.public_ip
}

output "mcp_server_url" {
  description = "MCP Server URL（Claude Desktop設定用）"
  value       = "http://${aws_eip.mcp_server.public_ip}:${var.mcp_server_port}/tableau-mcp"
}

output "ssh_command" {
  description = "SSH接続コマンド"
  value       = "ssh -i ~/.aws/${var.key_name}.pem ec2-user@${aws_eip.mcp_server.public_ip}"
}

output "setup_log_command" {
  description = "セットアップログ確認コマンド"
  value       = "ssh -i ~/.aws/${var.key_name}.pem ec2-user@${aws_eip.mcp_server.public_ip} 'tail -f /var/log/mcp-setup.log'"
}

output "service_status_command" {
  description = "サービスステータス確認コマンド"
  value       = "ssh -i ~/.aws/${var.key_name}.pem ec2-user@${aws_eip.mcp_server.public_ip} 'sudo systemctl status tableau-mcp'"
}

output "important_notes" {
  description = "使い方ガイド"
  value       = <<-EOT

    ======================================
    Tableau MCP Server デプロイ完了
    ======================================

    1. セットアップ完了確認（3-5分後）:
       ${aws_eip.mcp_server.public_ip} にSSH接続して以下を確認:
       $ tail -f /var/log/mcp-setup.log

    2. サービスステータス確認:
       $ sudo systemctl status tableau-mcp

    3. MCPサーバー接続テスト:
       $ curl -I http://${aws_eip.mcp_server.public_ip}:${var.mcp_server_port}/tableau-mcp

    4. Claude Desktop設定（settings.json）:
        {
          "mcpServers": {
            "tableau-mcp-remote": {
              "command": "npx",
              "args": [
                "mcp-remote",
                "http://${aws_eip.mcp_server.public_ip}:${var.mcp_server_port}/tableau-mcp",
                "--allow-http"
              ]
            }
          }
        }

    5. トラブルシューティング:
       $ sudo journalctl -u tableau-mcp -f

    EOT
}
