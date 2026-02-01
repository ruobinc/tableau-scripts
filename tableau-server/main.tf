#############################################
# Tableau Server on AWS - メインリソース定義
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
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

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

# 最新のAmazon Linux 2 AMIを取得
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#############################################
# ローカル変数
#############################################

locals {
  vpc_id    = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_id = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.default[0].ids[0]
  ami_id    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2.id

  # Tableauバージョンからダッシュ区切り文字列を生成
  tableau_version_dashed = replace(var.tableau_version, ".", "-")
}

#############################################
# EC2インスタンス
#############################################

resource "aws_instance" "tableau_server" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.tableau_server.id]

  # ルートボリューム
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # User Dataスクリプトを読み込み、変数を埋め込む
  user_data = templatefile("${path.module}/scripts/tableau-setup.sh", {
    tableau_version        = var.tableau_version
    tableau_version_dashed = local.tableau_version_dashed
    license_key            = var.license_key
    admin_username         = var.admin_username
    admin_password         = var.admin_password
    reg_first_name         = var.reg_first_name
    reg_last_name          = var.reg_last_name
    reg_email              = var.reg_email
    reg_company            = var.reg_company
    reg_title              = var.reg_title
    reg_department         = var.reg_department
    reg_phone              = var.reg_phone
    reg_city               = var.reg_city
    reg_state              = var.reg_state
    reg_zip                = var.reg_zip
    reg_country            = var.reg_country
    reg_industry           = var.reg_industry
    enable_https           = var.enable_https
  })

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }

  # IMDSv2を強制（AWSセキュリティベストプラクティス）
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # インスタンス作成完了を待つ
  lifecycle {
    create_before_destroy = true
  }
}

#############################################
# Elastic IP（固定IP）
#############################################

resource "aws_eip" "tableau_server" {
  instance = aws_instance.tableau_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip"
  }

  # インスタンスが作成されてからEIPを割り当てる
  depends_on = [aws_instance.tableau_server]
}

#############################################
# データ用EBSボリューム（オプション）
#############################################

resource "aws_ebs_volume" "tableau_data" {
  count             = var.data_volume_size > 0 ? 1 : 0
  availability_zone = var.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-${var.environment}-data"
  }
}

resource "aws_volume_attachment" "tableau_data" {
  count       = var.data_volume_size > 0 ? 1 : 0
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.tableau_data[0].id
  instance_id = aws_instance.tableau_server.id
}
