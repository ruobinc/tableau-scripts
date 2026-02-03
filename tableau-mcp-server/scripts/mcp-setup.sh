#!/bin/bash
#############################################
# Tableau MCP Server 自動セットアップスクリプト
#############################################
# このスクリプトはEC2起動時に自動実行されます
# ログ: /var/log/mcp-setup.log
#############################################

set -e

# ログ出力設定
exec > >(tee /var/log/mcp-setup.log | logger -t mcp-setup) 2>&1

echo "======================================"
echo "Tableau MCP Server セットアップ開始"
echo "開始時刻: $(date)"
echo "======================================"

#############################################
# Terraformから注入される変数
#############################################

# Tableau接続設定
TABLEAU_SERVER_URL="${tableau_server_url}"
TABLEAU_SITE_NAME="${tableau_site_name}"

# 認証設定
AUTH_METHOD="${auth_method}"
PAT_NAME="${pat_name}"
PAT_VALUE="${pat_value}"
CONNECTED_APP_CLIENT_ID="${connected_app_client_id}"
CONNECTED_APP_SECRET_ID="${connected_app_secret_id}"
CONNECTED_APP_SECRET_VALUE="${connected_app_secret_value}"
JWT_SUB_CLAIM="${jwt_sub_claim}"

# MCP Server設定
MCP_SERVER_PORT="${mcp_server_port}"
TRANSPORT_TYPE="${transport_type}"
LOG_LEVEL="${log_level}"

# 作業ディレクトリ
MCP_DIR="/opt/tableau-mcp"
SERVICE_USER="tableau-mcp"

#############################################
# フェーズ1: システム準備
#############################################

echo ""
echo "======================================"
echo "フェーズ1: システム準備"
echo "======================================"

# システム更新
echo "[INFO] システムを更新しています..."
dnf update -y

# 必要なパッケージをインストール
# 注意: Amazon Linux 2023にはcurl-minimalがプリインストールされているため、curlは不要
echo "[INFO] 必要なパッケージをインストールしています..."
dnf install -y git

echo "[INFO] システム準備が完了しました"

#############################################
# フェーズ2: Node.js 22.x インストール
#############################################

echo ""
echo "======================================"
echo "フェーズ2: Node.js 22.x インストール"
echo "======================================"

# NodeSourceリポジトリを追加してNode.js 22.xをインストール
echo "[INFO] Node.js 22.xをインストールしています..."
curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
dnf install -y nodejs

# バージョン確認
echo "[INFO] Node.jsバージョン: $(node --version)"
echo "[INFO] npmバージョン: $(npm --version)"

#############################################
# フェーズ3: サービスユーザー作成
#############################################

echo ""
echo "======================================"
echo "フェーズ3: サービスユーザー作成"
echo "======================================"

# tableau-mcpユーザーを作成（既存の場合はスキップ）
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "[INFO] サービスユーザー '$SERVICE_USER' を作成しています..."
    useradd --system --shell /bin/false --home-dir "$MCP_DIR" "$SERVICE_USER"
else
    echo "[INFO] サービスユーザー '$SERVICE_USER' は既に存在します"
fi

#############################################
# フェーズ4: Tableau MCPインストール
#############################################

echo ""
echo "======================================"
echo "フェーズ4: Tableau MCPインストール"
echo "======================================"

# 作業ディレクトリ作成
echo "[INFO] 作業ディレクトリを作成しています..."
mkdir -p "$MCP_DIR"

# Tableau MCPをクローン
echo "[INFO] Tableau MCPリポジトリをクローンしています..."
cd "$MCP_DIR"
if [ -d "$MCP_DIR/.git" ]; then
    echo "[INFO] リポジトリが既に存在するため、プルしています..."
    git pull
else
    git clone https://github.com/tableau/tableau-mcp.git .
fi

# 依存関係インストール
echo "[INFO] npm依存関係をインストールしています..."
npm install

# ビルド
echo "[INFO] Tableau MCPをビルドしています..."
npm run build

# 所有者変更
chown -R "$SERVICE_USER:$SERVICE_USER" "$MCP_DIR"

echo "[INFO] Tableau MCPのインストールが完了しました"

#############################################
# フェーズ5: 環境変数設定
#############################################

echo ""
echo "======================================"
echo "フェーズ5: 環境変数設定"
echo "======================================"

echo "[INFO] 環境変数ファイルを作成しています..."

# .envファイル作成
cat > "$MCP_DIR/.env" << EOF
# Tableau接続設定
SERVER=$TABLEAU_SERVER_URL
SITE=$TABLEAU_SITE_NAME

# 認証設定
AUTH=$AUTH_METHOD
EOF

# 認証方式に応じて追加設定
if [ "$AUTH_METHOD" = "pat" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# PAT認証
PAT_NAME=$PAT_NAME
PAT_VALUE=$PAT_VALUE
EOF
    echo "[INFO] PAT認証を設定しました"
elif [ "$AUTH_METHOD" = "direct-trust" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# Direct-Trust認証
CONNECTED_APP_CLIENT_ID=$CONNECTED_APP_CLIENT_ID
CONNECTED_APP_SECRET_ID=$CONNECTED_APP_SECRET_ID
CONNECTED_APP_SECRET_VALUE=$CONNECTED_APP_SECRET_VALUE
JWT_SUB_CLAIM=$JWT_SUB_CLAIM
EOF
    echo "[INFO] Direct-Trust認証を設定しました"
fi

# MCP Server設定を追加
cat >> "$MCP_DIR/.env" << EOF

# MCP Server設定
PORT=$MCP_SERVER_PORT
TRANSPORT=$TRANSPORT_TYPE
LOG_LEVEL=$LOG_LEVEL

# HTTP認証設定（開発/テスト環境用）
DANGEROUSLY_DISABLE_OAUTH=true

# 自己署名証明書を許可（開発/テスト環境用）
NODE_TLS_REJECT_UNAUTHORIZED=0
EOF

# パーミッション設定（機密情報を含むため）
chmod 600 "$MCP_DIR/.env"
chown "$SERVICE_USER:$SERVICE_USER" "$MCP_DIR/.env"

echo "[INFO] 環境変数ファイルの作成が完了しました"

#############################################
# フェーズ6: systemdサービス設定
#############################################

echo ""
echo "======================================"
echo "フェーズ6: systemdサービス設定"
echo "======================================"

echo "[INFO] systemdサービスファイルを作成しています..."

cat > /etc/systemd/system/tableau-mcp.service << EOF
[Unit]
Description=Tableau MCP Server
Documentation=https://github.com/tableau/tableau-mcp
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$MCP_DIR
EnvironmentFile=$MCP_DIR/.env
ExecStart=/usr/bin/node $MCP_DIR/build/index.js
Restart=on-failure
RestartSec=10

# セキュリティ設定
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$MCP_DIR

# ログ設定
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tableau-mcp

[Install]
WantedBy=multi-user.target
EOF

# systemdをリロード
systemctl daemon-reload

# サービスを有効化・起動
echo "[INFO] サービスを有効化・起動しています..."
systemctl enable tableau-mcp
systemctl start tableau-mcp

# 起動確認
sleep 5
if systemctl is-active --quiet tableau-mcp; then
    echo "[INFO] Tableau MCPサービスが正常に起動しました"
else
    echo "[ERROR] Tableau MCPサービスの起動に失敗しました"
    journalctl -u tableau-mcp --no-pager -n 50
    exit 1
fi

#############################################
# 最終確認
#############################################

echo ""
echo "======================================"
echo "セットアップ完了"
echo "完了時刻: $(date)"
echo "======================================"

# パブリックIP取得（IMDSv2対応）
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "アクセス情報:"
echo "  - MCP Server URL: http://$${PUBLIC_IP}:$${MCP_SERVER_PORT}/sse"
echo ""
echo "Claude Desktop設定（settings.json）:"
echo '  {'
echo '    "mcpServers": {'
echo '      "tableau-remote": {'
echo "        \"url\": \"http://$${PUBLIC_IP}:$${MCP_SERVER_PORT}/sse\""
echo '      }'
echo '    }'
echo '  }'
echo ""
echo "管理コマンド:"
echo "  - ステータス確認: sudo systemctl status tableau-mcp"
echo "  - ログ確認: sudo journalctl -u tableau-mcp -f"
echo "  - 再起動: sudo systemctl restart tableau-mcp"
echo ""

# サービスステータス表示
systemctl status tableau-mcp --no-pager || true
