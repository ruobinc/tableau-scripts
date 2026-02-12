#############################################
# Tableau MCP Server on AWS - 変数定義
#############################################

# AWS設定
variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "us-east-2"
}

variable "availability_zone" {
  description = "アベイラビリティゾーン"
  type        = string
  default     = "us-east-2a"
}

# EC2設定
variable "instance_type" {
  description = "EC2インスタンスタイプ（MCPサーバーは軽量なのでt3.smallで十分）"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID（空の場合は最新を自動取得）"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2キーペア名（SSH接続用）"
  type        = string
}

variable "root_volume_size" {
  description = "ルートボリュームサイズ（GB）- Amazon Linux 2023は最低30GB必要"
  type        = number
  default     = 30
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
}

variable "allowed_mcp_cidrs" {
  description = "MCP接続を許可するCIDRブロック"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Tableau接続設定
variable "tableau_server_url" {
  description = "Tableau Server/Cloud URL（例: https://your-server.com）"
  type        = string
}

variable "tableau_site_name" {
  description = "Tableauサイト名（デフォルトサイトの場合は空）"
  type        = string
  default     = ""
}

# 認証方式
variable "auth_method" {
  description = "認証方式: pat または direct-trust"
  type        = string
  default     = "pat"

  validation {
    condition     = contains(["pat", "direct-trust"], var.auth_method)
    error_message = "auth_methodは 'pat' または 'direct-trust' を指定してください"
  }
}

# PAT認証設定
variable "pat_name" {
  description = "Personal Access Token名"
  type        = string
  default     = ""
}

variable "pat_value" {
  description = "Personal Access Token値"
  type        = string
  default     = ""
  sensitive   = true
}

# Direct-Trust認証設定
variable "connected_app_client_id" {
  description = "Connected App Client ID"
  type        = string
  default     = ""
}

variable "connected_app_secret_id" {
  description = "Connected App Secret ID"
  type        = string
  default     = ""
}

variable "connected_app_secret_value" {
  description = "Connected App Secret Value"
  type        = string
  default     = ""
  sensitive   = true
}

variable "jwt_sub_claim" {
  description = "JWT Subject Claim（direct-trust認証のユーザー識別子）"
  type        = string
  default     = ""
}

# MCP Server設定
variable "mcp_server_port" {
  description = "MCPサーバーポート"
  type        = number
  default     = 3927
}

variable "transport_type" {
  description = "トランスポートタイプ（http または stdio）"
  type        = string
  default     = "http"
}

variable "log_level" {
  description = "ログレベル（debug, info, warn, error）"
  type        = string
  default     = "info"
}

variable "include_tools" {
  description = "有効化するツールのリスト（カンマ区切り）。exclude_toolsと同時に指定不可"
  type        = string
  default     = ""
}

variable "exclude_tools" {
  description = "除外するツールのリスト（カンマ区切り）。include_toolsと同時に指定不可"
  type        = string
  default     = ""
}

# タグ設定
variable "project_name" {
  description = "プロジェクト名（タグ用）"
  type        = string
  default     = "tableau-mcp-server"
}

variable "environment" {
  description = "環境（dev/staging/prod）"
  type        = string
  default     = "dev"
}

# HTTPS設定
variable "enable_https" {
  description = "HTTPSを有効化するか（443ポートを開放）"
  type        = bool
  default     = false
}

# プロキシ設定（Copilot Studio用）
variable "proxy_server_port" {
  description = "プロキシサーバーポート（Copilot Studio用）"
  type        = number
  default     = 3928
}

variable "enable_proxy" {
  description = "プロキシサーバーを有効化するか"
  type        = bool
  default     = true
}
