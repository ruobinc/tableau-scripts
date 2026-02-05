# Tableau MCP Server on AWS

TerraformでAWS EC2上にTableau MCPサーバーをデプロイする。

## ⚠️ 注意事項

この構成は**検証・学習目的**です。本番環境での使用は想定していません。
Copilot側MCPの制約により、Tableau MCPとのフォーマットと合わないため、プロキシサーバでフォーマットを変換を行っています。
あくまで検証する目的のため、推奨する方法ではありません。

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
terraform init && terraform plan && terraform apply -auto-approve

# 4. 確認（デプロイ後3-5分待機）
curl -I http://<PUBLIC_IP>:3928/tableau-mcp
```

## 接続
- URL: http://<PUBLIC_IP>:3928/tableau-mcp
- Claude Desktop: [claude_desktop_config_example.json](claude_desktop_config_example.json)

```

## 削除

```bash
terraform destroy -auto-approve
```

## 参考リンク

- [Tableau MCP GitHub](https://github.com/tableau/tableau-mcp)
- [Tableau Personal Access Tokens](https://help.tableau.com/current/server/en-us/security_personal_access_tokens.htm)
- [Tableau Connected Apps](https://help.tableau.com/current/server/en-us/connected_apps.htm)