# Tableau MCP Server on AWS

TerraformでAWS EC2上にTableau MCPサーバーをデプロイする。


## 前提条件

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/getting-started-install.html)

## 使い方

```bash
# 0. AWSプロファイルの設定(未設定の場合のみ)
aws configure sso

# 1. EC2キーペアを作成（キーを新規作成したい場合のみ）
../scripts/create-ec2-keypair.sh mcp-server-key

# 2. 設定
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集（AWS設定、Tableau認証情報）

# 3. デプロイ
export AWS_PROFILE=your-profile-name
aws sso login
terraform init && terraform apply -auto-approve

# 4. 確認（デプロイ後3-5分待機）
curl -I http://<PUBLIC_IP>:3927/tableau-mcp
```

## 接続
- URL: http://<PUBLIC_IP>:3927/tableau-mcp
- Claude Desktop: [claude_desktop_config_example.json](claude_desktop_config_example.json)

## 設定変更の反映

```bash
terraform taint aws_instance.mcp_server && terraform apply -auto-approve
```

※ Elastic IPが設定されているため、IPアドレスは変わらない

## トラブルシューティング

```bash
# ログ確認
ssh -i ~/.aws/your-key.pem ec2-user@<DNS> 'cat /var/log/mcp-setup.log'
ssh -i ~/.aws/your-key.pem ec2-user@<DNS> 'sudo journalctl -u tableau-mcp -f'

# 再起動
ssh -i ~/.aws/your-key.pem ec2-user@<DNS> 'sudo systemctl restart tableau-mcp'
```

## 削除

```bash
terraform destroy -auto-approve
```

## 参考リンク

- [Tableau MCP GitHub](https://github.com/tableau/tableau-mcp)
- [Tableau Personal Access Tokens](https://help.tableau.com/current/server/en-us/security_personal_access_tokens.htm)
- [Tableau Connected Apps](https://help.tableau.com/current/server/en-us/connected_apps.htm)