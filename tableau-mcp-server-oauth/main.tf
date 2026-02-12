#############################################
# Tableau MCP Server on AWS - メインリソース定義
#############################################

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

#############################################
# データソース
#############################################

# デフォルトVPCを取得（vpc_idが指定されていない場合）
data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

# デフォルトサブネットを取得（subnet_idが指定されていない場合）
data "aws_subnets" "default" {
  count = var.subnet_id == "" ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }
}

# 最新のAmazon Linux 2023 AMIを取得
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

#############################################
# ローカル変数
#############################################

locals {
  vpc_id    = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_id = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.default[0].ids[0]
  ami_id    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
}

#############################################
# EC2インスタンス
#############################################

resource "aws_instance" "mcp_server" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.mcp_server.id]

  # ルートボリューム
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # User Dataスクリプトを読み込み、変数を埋め込む（Base64エンコード）
  user_data_base64 = base64gzip(templatefile("${path.module}/scripts/mcp-setup.sh", {
    # Tableau接続設定
    tableau_server_url = var.tableau_server_url
    tableau_site_name  = var.tableau_site_name

    # 認証設定
    auth_method                = var.auth_method
    pat_name                   = var.pat_name
    pat_value                  = var.pat_value
    connected_app_client_id    = var.connected_app_client_id
    connected_app_secret_id    = var.connected_app_secret_id
    connected_app_secret_value = var.connected_app_secret_value
    jwt_sub_claim              = var.jwt_sub_claim

    # OAuth認証設定（MCP ServerがIssuerとして動作）
    oauth_lock_site = var.oauth_lock_site
    cors_origin     = var.cors_origin

    # MCP設定
    mcp_server_port = var.mcp_server_port
    transport_type  = var.transport_type
    log_level       = var.log_level
    include_tools   = var.include_tools
    exclude_tools   = var.exclude_tools

    # HTTPS/SSL設定
    enable_https  = var.enable_https
    mcp_ssl_cn    = var.mcp_ssl_cert_cn
    mcp_ssl_org   = var.mcp_ssl_org
    mcp_ssl_email = var.mcp_ssl_email

    # Tableau Server SSL証明書
    tableau_ssl_cert = var.tableau_ssl_cert

    # Tableau Server OAuth自動設定
    configure_tableau_oauth     = var.configure_tableau_oauth
    tableau_server_host         = var.tableau_server_host
    tableau_server_ssh_user     = var.tableau_server_ssh_user
    tableau_server_ssh_key_path = var.tableau_server_ssh_key_path
    tableau_container_name      = var.tableau_container_name
    key_name                    = var.key_name
  }))

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }

  # IMDSv2を強制（AWSセキュリティベストプラクティス）
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

#############################################
# Elastic IP（固定IP）
#############################################

resource "aws_eip" "mcp_server" {
  instance = aws_instance.mcp_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }
}
