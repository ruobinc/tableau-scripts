#############################################
# Tableau MCP Server - セキュリティグループ
#############################################

resource "aws_security_group" "mcp_server" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for Tableau MCP Server"
  vpc_id      = local.vpc_id

  # SSH (22)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # MCP Server (3927)
  ingress {
    description = "MCP Server access"
    from_port   = var.mcp_server_port
    to_port     = var.mcp_server_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_mcp_cidrs
  }

  # HTTPS (443) - オプション
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS access"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_mcp_cidrs
    }
  }

  # Proxy Server (3928) - Copilot Studio用
  dynamic "ingress" {
    for_each = var.enable_proxy ? [1] : []
    content {
      description = "MCP Proxy Server access (Copilot Studio)"
      from_port   = var.proxy_server_port
      to_port     = var.proxy_server_port
      protocol    = "tcp"
      cidr_blocks = var.allowed_mcp_cidrs
    }
  }

  # Outbound: 全ての外向きトラフィックを許可（Tableau API接続のため）
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
