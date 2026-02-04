# Tableau Server 自動構築（Terraform）

EC2上にTableau Serverを自動構築します。

## ⚠️ 注意事項

この構成は**検証・学習目的**です。本番環境での使用は想定していません。

## 前提条件

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [AWS CLI](https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/getting-started-install.html)

## 手順

```bash
# 0. AWSプロファイルの設定
aws configure sso

# 1. AWS認証
export AWS_PROFILE=your-profile-name
aws sso login

# 2. EC2キーペアを作成（キー作成が必要な場合のみ実行）
# キーは ../.aws/tableau-server-key.pem に保存される
../scripts/create-ec2-keypair.sh tableau-server-key

# 3. 変数ファイルを作成・編集
cp terraform.tfvars.example terraform.tfvars

# 4. 実行（完了まで約40-50分）
terraform init && terraform plan && terraform apply -auto-approve
```

## アクセス

- HTTP: `http://<IP>:8080`
- HTTPS: `https://<IP>`

## 削除

```bash
terraform destroy -auto-approve
```
