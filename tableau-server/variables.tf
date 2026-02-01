#############################################
# Tableau Server on AWS - 変数定義
#############################################

# AWS設定
variable "aws_profile" {
  description = "AWS CLIプロファイル名（SSO認証用）。空の場合は環境変数AWS_PROFILEまたはデフォルトを使用"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "アベイラビリティゾーン"
  type        = string
  default     = "us-east-1a"
}

# EC2設定
variable "instance_type" {
  description = "EC2インスタンスタイプ（Tableau Serverには32GB以上のRAMを推奨。r6i.xlarge=32GB, r6i.2xlarge=64GB）"
  type        = string
  default     = "r6i.xlarge"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID（リージョンにより異なる）"
  type        = string
  default     = "" # 空の場合は最新のAmazon Linux 2を自動取得
}

variable "key_name" {
  description = "EC2キーペア名（SSH接続用）"
  type        = string
}

variable "root_volume_size" {
  description = "ルートボリュームサイズ（GB）"
  type        = number
  default     = 100
}

variable "data_volume_size" {
  description = "データボリュームサイズ（GB）- Tableau永続データ用"
  type        = number
  default     = 200
}

# ネットワーク設定
variable "vpc_id" {
  description = "VPC ID（デフォルトVPCを使用する場合は空）"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "サブネットID（デフォルトVPCを使用する場合は空）"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "SSH接続を許可するCIDRブロック（セキュリティのため必ず指定してください）"
  type        = list(string)
  # デフォルトなし - 必ず明示的に指定が必要
}

variable "allowed_http_cidrs" {
  description = "HTTP/HTTPS接続を許可するCIDRブロック"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Tableau Server設定
variable "tableau_version" {
  description = "Tableau Serverのバージョン（https://www.tableau.com/support/releases/server で確認）"
  type        = string
  default     = "2025.3.2"
}

variable "license_key" {
  description = "Tableau Serverライセンスキー"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Tableau Server管理者ユーザー名"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Tableau Server管理者パスワード"
  type        = string
  sensitive   = true
}

# 登録情報
variable "reg_first_name" {
  description = "登録者の名"
  type        = string
}

variable "reg_last_name" {
  description = "登録者の姓"
  type        = string
}

variable "reg_email" {
  description = "登録者のメールアドレス"
  type        = string
}

variable "reg_company" {
  description = "会社名"
  type        = string
}

variable "reg_title" {
  description = "役職"
  type        = string
  default     = "Engineer"
}

variable "reg_department" {
  description = "部署"
  type        = string
  default     = "IT"
}

variable "reg_phone" {
  description = "電話番号"
  type        = string
  default     = ""
}

variable "reg_city" {
  description = "都市"
  type        = string
  default     = "Tokyo"
}

variable "reg_state" {
  description = "都道府県"
  type        = string
  default     = "Tokyo"
}

variable "reg_zip" {
  description = "郵便番号"
  type        = string
  default     = "100-0001"
}

variable "reg_country" {
  description = "国"
  type        = string
  default     = "Japan"
}

variable "reg_industry" {
  description = "業種"
  type        = string
  default     = "Technology"
}

# タグ設定
variable "project_name" {
  description = "プロジェクト名（タグ用）"
  type        = string
  default     = "tableau-server"
}

variable "environment" {
  description = "環境（dev/staging/prod）"
  type        = string
  default     = "dev"
}

# HTTPS設定
variable "enable_https" {
  description = "HTTPSを有効化するか"
  type        = bool
  default     = true
}
