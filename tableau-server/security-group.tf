#############################################
# Tableau Server - セキュリティグループ
#############################################

resource "aws_security_group" "tableau_server" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for Tableau Server"
  vpc_id      = local.vpc_id

  # SSH (22)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HTTP (8080) - Tableau Server default HTTP port
  ingress {
    description = "Tableau Server HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # HTTPS (443)
  ingress {
    description = "Tableau Server HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # Outbound: 全ての外向きトラフィックを許可
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}
