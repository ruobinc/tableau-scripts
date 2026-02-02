# Tableau Server 自動構築（Terraform）

EC2上にTableau Serverを自動構築します。

## 前提条件

- Terraform v1.0以上
- AWS CLI認証済み（SSO対応）
- EC2キーペア作成済み

## 手順

```bash
# 1. 変数ファイルを作成・編集
cp terraform.tfvars.example terraform.tfvars

# 2. AWS認証
export AWS_PROFILE=your-profile-name
aws sso login

# 3. 実行（完了まで約40-50分）
terraform init
terraform plan
terraform apply
```

## アクセス

- HTTP: `http://<IP>:8080`
- HTTPS: `https://<IP>`

## 削除

```bash
terraform destroy
```

## トラブルシューティング

[DEBUG.md](DEBUG.md) を参照。
