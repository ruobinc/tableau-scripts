# Tableau Server 自動構築（Terraform）

EC2上にTableau Serverを自動構築します。

## 前提条件

- Terraformインストール済み（v1.0以上）
- AWS CLIで認証済み（SSO対応）
- EC2キーペアを作成済み
- VPN接続可能（SSHアクセス制限している場合）

## 手順

### 1. 変数ファイルを作成

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. terraform.tfvarsを編集

必須項目を設定：

```hcl
# AWS認証（方法1: tfvarsで指定）
aws_profile    = "your-aws-profile"      # AWS CLIプロファイル名

key_name       = "your-key-pair-name"    # EC2キーペア名
license_key    = "XXXX-XXXX-XXXX-XXXX"   # Tableauライセンス
admin_password = "YourPassword123"        # 管理者パスワード
reg_first_name = "Taro"
reg_last_name  = "Yamada"
reg_email      = "your@email.com"
reg_company    = "Your Company"

# SSHアクセス制限（必須 - VPN経由のCIDRなど）
allowed_ssh_cidrs = ["YOUR_VPN_CIDR/24"]
```

### 3. AWS認証

```bash
aws sso login --profile YOUR_PROFILE_NAME
```

### 4. 実行

**方法1: terraform.tfvarsでaws_profileを指定した場合**
```bash
terraform init
terraform plan
terraform apply
```

**方法2: 環境変数で指定する場合**
```bash
export AWS_PROFILE=YOUR_PROFILE_NAME
terraform init
terraform plan
terraform apply
```

**方法3: コマンドごとに指定する場合**
```bash
AWS_PROFILE=YOUR_PROFILE_NAME terraform init
AWS_PROFILE=YOUR_PROFILE_NAME terraform plan
AWS_PROFILE=YOUR_PROFILE_NAME terraform apply
```

> **注意**: AWS SSOを使用する場合、プロファイル指定は必須です。
> 認証情報は`~/.aws/sso/cache/`に保存され、Terraformがこれを読み取るにはプロファイル名が必要です。

### 5. 完了を待つ

初期化完了まで約40-50分かかります。

ログ確認（VPN接続が必要な場合あり）：
```bash
# DNS名で接続（推奨）
ssh -i /path/to/your-key.pem ec2-user@ec2-x-x-x-x.region.compute.amazonaws.com "tail -f /var/log/tableau-setup.log"

# ホストキーエラーが出た場合は、古いエントリを削除してから再接続
ssh-keygen -R ec2-x-x-x-x.region.compute.amazonaws.com
ssh -i /path/to/your-key.pem ec2-user@ec2-x-x-x-x.region.compute.amazonaws.com "tail -f /var/log/tableau-setup.log"
```

### 6. アクセス

- HTTP: `http://<IP>:8080`
- HTTPS: `https://<IP>`

初回アクセス時にadminユーザーでログインできます。

## 削除

```bash
terraform destroy
```

> aws_profileをterraform.tfvarsで指定していない場合は、`AWS_PROFILE=YOUR_PROFILE_NAME terraform destroy`を使用してください。

## 注意事項

### SSHアクセスについて

- `allowed_ssh_cidrs`でSSHアクセス元を制限している場合、VPN接続が必要です
- AWS Public DNS名（例: `ec2-x-x-x-x.region.compute.amazonaws.com`）でSSH接続してください
- IPアドレス直接指定では接続できない場合があります

### SSL証明書について

- 自己署名証明書を使用しています
- ブラウザで「安全でない接続」の警告が表示されますが、テスト環境では問題ありません
- 本番環境ではACMなどで正式な証明書を設定してください

## トラブルシューティング

[DEBUG.md](DEBUG.md) を参照。
