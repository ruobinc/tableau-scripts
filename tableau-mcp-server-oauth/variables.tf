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
  description = "認証方式: pat, direct-trust, または oauth"
  type        = string
  default     = "oauth"

  validation {
    condition     = contains(["pat", "direct-trust", "oauth"], var.auth_method)
    error_message = "auth_methodは 'pat', 'direct-trust', または 'oauth' を指定してください"
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

#############################################
# HTTPS/SSL設定
#############################################

variable "enable_https" {
  description = "MCP ServerでHTTPSを有効化（自己署名証明書を自動生成）"
  type        = bool
  default     = true
}

variable "mcp_ssl_cert_cn" {
  description = "SSL証明書のCommon Name（空の場合はEC2パブリックDNSを使用）"
  type        = string
  default     = ""
}

variable "mcp_ssl_org" {
  description = "SSL証明書の組織名"
  type        = string
  default     = "Organization"
}

variable "mcp_ssl_email" {
  description = "SSL証明書のメールアドレス"
  type        = string
  default     = "admin@example.com"
}

#############################################
# Tableau Server SSH設定（OAuth自動設定用）
#############################################

variable "tableau_server_host" {
  description = "Tableau ServerのSSH接続先ホスト（EC2 DNS推奨）"
  type        = string
  default     = ""
}

variable "tableau_server_ssh_user" {
  description = "Tableau ServerへのSSHユーザー名"
  type        = string
  default     = "ec2-user"
}

variable "tableau_server_ssh_key_path" {
  description = "Tableau ServerへのSSH秘密鍵パス（EC2上のパス）"
  type        = string
  default     = ""
}

variable "tableau_container_name" {
  description = "Tableau Serverのコンテナ名（Docker使用時）"
  type        = string
  default     = "tableau-server"
}

variable "configure_tableau_oauth" {
  description = "Tableau ServerのOAuth redirect hostを自動設定するか"
  type        = bool
  default     = false
}

#############################################
# OAuth認証設定（MCP ServerがIssuerとして動作）
#############################################

variable "oauth_lock_site" {
  description = "OAuthサイトロック有効化"
  type        = bool
  default     = true
}

variable "cors_origin" {
  description = "CORS許可オリジン（'*'または特定URL）"
  type        = string
  default     = "*"
}

#############################################
# Tableau Server SSL証明書（MCP Serverが信頼するため）
#############################################

variable "tableau_ssl_cert" {
  description = "Tableau ServerのSSL証明書（PEM形式、自己署名証明書の場合に必要）"
  type        = string
  default     = ""
}
