# Tableau MCP Server OAuth版 on AWS

TerraformでAWS EC2上にOAuth認証対応のTableau MCPサーバーをデプロイする。
MCP ServerがOAuth Issuerとして動作し、Tableau Serverの認証フローを処理する。

## ⚠️ 注意事項

この構成は**検証・学習目的**です。本番環境での使用は想定していません。

## 前提条件

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/getting-started-install.html)
- Tableau Server（OAuth対応設定済み）

## 使い方

```bash
# 0. AWSプロファイルの設定(未設定の場合のみ)
aws configure sso

# 1. EC2キーペアを作成（キーを新規作成したい場合のみ）
../scripts/create-ec2-keypair.sh tableau-mcp-key

# 2. 設定
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvarsを編集

# 3. デプロイ
export AWS_PROFILE=your-profile-name
aws sso login
terraform init && terraform apply -auto-approve

# 4. Tableau ServerのOAuth設定
#    MCP ServerのDNSをredirect_uri_hostsに追加する
#    https://tableau.github.io/tableau-mcp/docs/configuration/mcp-config/oauth#oauth_redirect_uri
#    Tableau Serverで以下を実行:
tsm configuration set -k oauth.allowed_redirect_uri_hosts -v "<MCP_SERVER_DNS>,<MCP_SERVER_DNS>:3927"
tsm pending-changes apply

# 5. 出力されるClaude Desktop設定をコピーして設定
```

## Claude Desktop設定

`terraform apply` 後に出力される `claude_desktop_config` をコピーして設定。

```json
{
  "mcpServers": {
    "tableau-mcp-oauth": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://<MCP_SERVER_DNS>:3927/tableau-mcp",
        "--static-oauth-client-info",
        "{\"client_id\":\"mcp-public-client\",\"token_endpoint_auth_method\":\"none\"}"
      ],
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

## トラブルシューティング

### よくあるエラー

| エラー | 原因 | 解決策 |
|--------|------|--------|
| `invalid_request` | Tableau Serverのredirect_uri_hosts未設定 | terraform出力のOAuthコマンドを実行 |
| `SSE stream disconnected` | 接続タイムアウト | MCP Serverを再起動 |
| `certificate verify failed` | 自己署名証明書 | `NODE_TLS_REJECT_UNAUTHORIZED=0`を設定 |

### ログ確認

```bash
# MCP Serverログ
ssh -i ~/.aws/your-key.pem ec2-user@<MCP_DNS> 'sudo journalctl -u tableau-mcp -f'

# OAuthエンドポイント確認
curl -k https://<MCP_DNS>:3927/.well-known/oauth-authorization-server
```

## 設定変更の反映

```bash
terraform taint aws_instance.mcp_server && terraform apply -auto-approve
```

## 削除

```bash
terraform destroy -auto-approve
```

## 参考リンク

- [Tableau MCP GitHub](https://github.com/tableau/tableau-mcp)
- [Tableau OAuth Configuration](https://help.tableau.com/current/server/en-us/oauth_config.htm)
- [mcp-remote](https://www.npmjs.com/package/mcp-remote)
