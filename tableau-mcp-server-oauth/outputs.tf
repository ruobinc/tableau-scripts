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

output "public_dns" {
  description = "EC2パブリックDNS（Elastic IPベース）"
  value       = aws_eip.mcp_server.public_dns
}

output "mcp_server_url" {
  description = "MCP Server URL"
  value       = var.enable_https ? "https://${aws_eip.mcp_server.public_dns}:${var.mcp_server_port}/tableau-mcp" : "http://${aws_eip.mcp_server.public_ip}:${var.mcp_server_port}/tableau-mcp"
}

output "ssh_command" {
  description = "SSH接続コマンド"
  value       = "ssh -i ../.aws/${var.key_name}.pem ec2-user@${aws_eip.mcp_server.public_dns}"
}

output "tableau_server_oauth_command" {
  description = "Tableau Server OAuth設定コマンド"
  value       = <<-EOT
# Tableau ServerにSSH接続後、以下を実行:
tsm configuration set \
  -k oauth.allowed_redirect_uri_hosts \
  -v "${aws_eip.mcp_server.public_dns},${aws_eip.mcp_server.public_dns}:${var.mcp_server_port}"

tsm pending-changes apply --ignore-prompt --request-timeout 1800

# Note: コンテナ環境の場合は各コマンドの先頭に「docker exec <コンテナ名>」を追加してください
EOT
}

output "claude_desktop_config" {
  description = "Claude Desktop設定JSON"
  value       = <<-EOT
{
  "mcpServers": {
    "tableau-mcp-oauth": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "${var.enable_https ? "https" : "http"}://${aws_eip.mcp_server.public_dns}:${var.mcp_server_port}/tableau-mcp",
        "--static-oauth-client-info",
        "{\"client_id\":\"mcp-public-client\",\"token_endpoint_auth_method\":\"none\"}"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
EOT
}

output "important_notes" {
  description = "使い方ガイド"
  value       = <<-EOT

======================================
Tableau MCP Server (OAuth版) デプロイ完了
======================================

MCP Server DNS: ${aws_eip.mcp_server.public_dns}

--------------------------------------
Step 1: セットアップ完了確認（3-5分後）
--------------------------------------
ssh -i ../.aws/${var.key_name}.pem ec2-user@${aws_eip.mcp_server.public_dns} 'tail -f /var/log/mcp-setup.log'

--------------------------------------
Step 2: Tableau Server OAuth設定（初回のみ）
--------------------------------------
Tableau ServerにSSH接続後、以下を実行:

tsm configuration set \
  -k oauth.allowed_redirect_uri_hosts \
  -v "${aws_eip.mcp_server.public_dns},${aws_eip.mcp_server.public_dns}:${var.mcp_server_port}"

tsm pending-changes apply --ignore-prompt --request-timeout 1800

※ コンテナ環境の場合は各コマンドの先頭に「docker exec <コンテナ名>」を追加

--------------------------------------
Step 3: Claude Desktop設定
--------------------------------------
~/Library/Application Support/Claude/claude_desktop_config.json:

{
  "mcpServers": {
    "tableau-mcp-oauth": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "${var.enable_https ? "https" : "http"}://${aws_eip.mcp_server.public_dns}:${var.mcp_server_port}/tableau-mcp",
        "--static-oauth-client-info",
        "{\"client_id\":\"mcp-public-client\",\"token_endpoint_auth_method\":\"none\"}"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}

--------------------------------------
トラブルシューティング
--------------------------------------
# MCP Serverログ
ssh -i ../.aws/${var.key_name}.pem ec2-user@${aws_eip.mcp_server.public_dns} 'sudo journalctl -u tableau-mcp -f'

# OAuthエンドポイント確認
curl -k ${var.enable_https ? "https" : "http"}://${aws_eip.mcp_server.public_dns}:${var.mcp_server_port}/.well-known/oauth-authorization-server

EOT
}
