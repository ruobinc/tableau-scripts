#!/bin/bash
# Content-Type: multipart/x-shellscript; charset="utf-8"
# MIME-Version: 1.0
#############################################
# Tableau MCP Server 自動セットアップスクリプト
# OAuth版（MCP ServerがOAuth Issuerとして動作）
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

# OAuth認証設定（MCP ServerがIssuerとして動作）
OAUTH_LOCK_SITE="${oauth_lock_site}"
CORS_ORIGIN="${cors_origin}"

# MCP Server設定
MCP_SERVER_PORT="${mcp_server_port}"
TRANSPORT_TYPE="${transport_type}"
LOG_LEVEL="${log_level}"
INCLUDE_TOOLS="${include_tools}"
EXCLUDE_TOOLS="${exclude_tools}"

# HTTPS/SSL設定
ENABLE_HTTPS="${enable_https}"
MCP_SSL_CN="${mcp_ssl_cn}"
MCP_SSL_ORG="${mcp_ssl_org}"
MCP_SSL_EMAIL="${mcp_ssl_email}"

# Tableau Server SSL証明書
TABLEAU_SSL_CERT="${tableau_ssl_cert}"

# Tableau Server OAuth自動設定
CONFIGURE_TABLEAU_OAUTH="${configure_tableau_oauth}"
TABLEAU_SERVER_HOST="${tableau_server_host}"
TABLEAU_SERVER_SSH_USER="${tableau_server_ssh_user}"
TABLEAU_SERVER_SSH_KEY_PATH="${tableau_server_ssh_key_path}"
TABLEAU_CONTAINER_NAME="${tableau_container_name}"
KEY_NAME="${key_name}"

# 作業ディレクトリ
MCP_DIR="/opt/tableau-mcp"
SERVICE_USER="tableau-mcp"
MCP_SSL_DIR="/opt/tableau-mcp-ssl"
MCP_KEY_DIR="/opt/tableau-mcp-keys"

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
echo "[INFO] 必要なパッケージをインストールしています..."
dnf install -y git openssl

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
mkdir -p "$MCP_SSL_DIR"
mkdir -p "$MCP_KEY_DIR"

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

echo "[INFO] Tableau MCPのインストールが完了しました"

#############################################
# フェーズ5: JWE秘密鍵の生成
#############################################

echo ""
echo "======================================"
echo "フェーズ5: JWE秘密鍵の生成"
echo "======================================"

MCP_JWE_PRIVATE_KEY_PATH="$MCP_KEY_DIR/mcp-jwe-private.pem"

if [ -f "$MCP_JWE_PRIVATE_KEY_PATH" ]; then
    echo "[INFO] JWE秘密鍵が既に存在します: $MCP_JWE_PRIVATE_KEY_PATH"
else
    echo "[INFO] JWE秘密鍵を生成しています..."
    openssl genrsa -out "$MCP_JWE_PRIVATE_KEY_PATH" 2048
    chmod 600 "$MCP_JWE_PRIVATE_KEY_PATH"
    echo "[INFO] JWE秘密鍵を生成しました: $MCP_JWE_PRIVATE_KEY_PATH"
fi

#############################################
# フェーズ6: SSL証明書の生成（HTTPS有効時）
#############################################

echo ""
echo "======================================"
echo "フェーズ6: SSL証明書の設定"
echo "======================================"

# パブリックIP/DNS取得（IMDSv2対応）
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
PUBLIC_DNS=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)

# CNの決定
if [ -n "$MCP_SSL_CN" ]; then
    SSL_CN="$MCP_SSL_CN"
else
    SSL_CN="$PUBLIC_DNS"
fi

MCP_SSL_CERT="$MCP_SSL_DIR/server.crt"
MCP_SSL_KEY="$MCP_SSL_DIR/server.key"

if [ "$ENABLE_HTTPS" = "true" ]; then
    if [ ! -f "$MCP_SSL_CERT" ] || [ ! -f "$MCP_SSL_KEY" ]; then
        echo "[INFO] 自己署名SSL証明書を生成しています..."

        # SAN設定ファイル作成
        cat > "$MCP_SSL_DIR/san.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=JP
ST=Tokyo
L=Tokyo
O=$MCP_SSL_ORG
OU=Tableau MCP
CN=$SSL_CN
emailAddress=$MCP_SSL_EMAIL

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SSL_CN
IP.1 = $PUBLIC_IP
DNS.2 = localhost
EOF

        # 秘密鍵生成
        openssl genrsa -out "$MCP_SSL_KEY" 2048

        # CSR生成
        openssl req -new -key "$MCP_SSL_KEY" -out "$MCP_SSL_DIR/server.csr" -config "$MCP_SSL_DIR/san.cnf"

        # 証明書生成
        openssl x509 -req -days 365 -in "$MCP_SSL_DIR/server.csr" -signkey "$MCP_SSL_KEY" \
            -out "$MCP_SSL_CERT" -extensions v3_req -extfile "$MCP_SSL_DIR/san.cnf"

        chmod 600 "$MCP_SSL_KEY"
        echo "[INFO] SSL証明書を生成しました"
        echo "[INFO]   CN: $SSL_CN"
        echo "[INFO]   SAN: DNS.1=$SSL_CN, IP.1=$PUBLIC_IP"
    else
        echo "[INFO] SSL証明書が既に存在します"
    fi

    MCP_PROTOCOL="https"
else
    echo "[INFO] HTTPSは無効です。HTTPで動作します。"
    MCP_PROTOCOL="http"
    MCP_SSL_CERT=""
    MCP_SSL_KEY=""
fi

# MCP Issuer URL（MCP Server自身がIssuerとして動作）
MCP_ISSUER="$${MCP_PROTOCOL}://$${SSL_CN}:$${MCP_SERVER_PORT}"

echo "[INFO] MCP Issuer URL: $MCP_ISSUER"

#############################################
# フェーズ7: Tableau Server SSL証明書の設定
#############################################

echo ""
echo "======================================"
echo "フェーズ7: Tableau Server SSL証明書の設定"
echo "======================================"

TABLEAU_SSL_CERT_PATH=""

if [ -n "$TABLEAU_SSL_CERT" ]; then
    TABLEAU_SSL_CERT_PATH="$MCP_DIR/tableau-server.crt"
    echo "$TABLEAU_SSL_CERT" > "$TABLEAU_SSL_CERT_PATH"
    chmod 644 "$TABLEAU_SSL_CERT_PATH"
    echo "[INFO] Tableau Server SSL証明書を保存しました: $TABLEAU_SSL_CERT_PATH"
else
    echo "[INFO] Tableau Server SSL証明書は指定されていません"
fi

#############################################
# フェーズ8: 環境変数設定
#############################################

echo ""
echo "======================================"
echo "フェーズ8: 環境変数設定"
echo "======================================"

echo "[INFO] 環境変数ファイルを作成しています..."

# .envファイル作成
cat > "$MCP_DIR/.env" << EOF
# Tableau接続設定
SERVER=$TABLEAU_SERVER_URL
SITE_NAME=$TABLEAU_SITE_NAME

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
elif [ "$AUTH_METHOD" = "oauth" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# OAuth認証（MCP ServerがIssuerとして動作）
OAUTH_ISSUER=$MCP_ISSUER
OAUTH_JWE_PRIVATE_KEY_PATH=$MCP_JWE_PRIVATE_KEY_PATH
OAUTH_LOCK_SITE=$OAUTH_LOCK_SITE
EOF
    echo "[INFO] OAuth認証を設定しました（MCP ServerがIssuer）"
fi

# MCP Server設定を追加
cat >> "$MCP_DIR/.env" << EOF

# MCP Server設定
PORT=$MCP_SERVER_PORT
TRANSPORT=$TRANSPORT_TYPE
DEFAULT_LOG_LEVEL=$LOG_LEVEL
EOF

# HTTPS設定
if [ "$ENABLE_HTTPS" = "true" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# SSL設定
SSL_CERT=$MCP_SSL_CERT
SSL_KEY=$MCP_SSL_KEY
EOF
fi

# Tableau Server SSL証明書（自己署名証明書を信頼するため）
if [ -n "$TABLEAU_SSL_CERT_PATH" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# Tableau Server SSL証明書
NODE_EXTRA_CA_CERTS=$TABLEAU_SSL_CERT_PATH
EOF
fi

# ツールフィルタリング設定（空でない場合のみ追加）
if [ -n "$INCLUDE_TOOLS" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# ツールフィルタリング（有効化）
INCLUDE_TOOLS=$INCLUDE_TOOLS
EOF
    echo "[INFO] INCLUDE_TOOLS を設定しました: $INCLUDE_TOOLS"
elif [ -n "$EXCLUDE_TOOLS" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# ツールフィルタリング（除外）
EXCLUDE_TOOLS=$EXCLUDE_TOOLS
EOF
    echo "[INFO] EXCLUDE_TOOLS を設定しました: $EXCLUDE_TOOLS"
fi

# CORS設定
if [ -n "$CORS_ORIGIN" ]; then
    echo "CORS_ORIGIN_CONFIG=$CORS_ORIGIN" >> "$MCP_DIR/.env"
fi

# HTTP認証設定（OAuthの場合は無効化しない）
if [ "$AUTH_METHOD" != "oauth" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# HTTP認証設定（開発/テスト環境用）
DANGEROUSLY_DISABLE_OAUTH=true
EOF
fi

# 自己署名証明書を許可（開発/テスト環境用）- Tableau Serverとの通信用
if [ -z "$TABLEAU_SSL_CERT_PATH" ]; then
    cat >> "$MCP_DIR/.env" << EOF

# 自己署名証明書を許可（開発/テスト環境用）
NODE_TLS_REJECT_UNAUTHORIZED=0
EOF
fi

# パーミッション設定（機密情報を含むため）
chmod 600 "$MCP_DIR/.env"

# 所有者変更
chown -R "$SERVICE_USER:$SERVICE_USER" "$MCP_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$MCP_SSL_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$MCP_KEY_DIR"

echo "[INFO] 環境変数ファイルの作成が完了しました"

#############################################
# フェーズ9: Tableau Server OAuth設定（オプション）
#############################################

echo ""
echo "======================================"
echo "フェーズ9: Tableau Server OAuth設定"
echo "======================================"

if [ "$CONFIGURE_TABLEAU_OAUTH" = "true" ] && [ -n "$TABLEAU_SERVER_HOST" ]; then
    echo "[INFO] Tableau ServerのOAuth redirect hostを設定しています..."

    MCP_REDIRECT_HOST="$SSL_CN:$MCP_SERVER_PORT"
    MCP_REDIRECT_HOST_NO_PORT="$SSL_CN"

    # SSH秘密鍵をコピー（Terraformで指定されたパスから）
    SSH_KEY_PATH="/home/ec2-user/.ssh/$KEY_NAME.pem"

    if [ -n "$TABLEAU_SERVER_SSH_KEY_PATH" ] && [ -f "$TABLEAU_SERVER_SSH_KEY_PATH" ]; then
        SSH_KEY_PATH="$TABLEAU_SERVER_SSH_KEY_PATH"
    fi

    if [ -f "$SSH_KEY_PATH" ]; then
        echo "[INFO] SSHでTableau Serverに接続しています..."

        # 現在のOAuth redirect hostsを取得
        CURRENT_HOSTS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$TABLEAU_SERVER_SSH_USER@$TABLEAU_SERVER_HOST" \
            "docker exec $TABLEAU_CONTAINER_NAME tsm configuration get -k oauth.allowed_redirect_uri_hosts --trust-admin-controller-cert 2>/dev/null | awk -F': ' 'NF>1 {print \$2}' | tail -1" 2>/dev/null || echo "")

        NEW_HOSTS="$CURRENT_HOSTS"
        if [ -z "$NEW_HOSTS" ]; then
            NEW_HOSTS="$MCP_REDIRECT_HOST_NO_PORT,$MCP_REDIRECT_HOST"
        fi

        # ホストを追加（重複チェック）
        if ! echo "$NEW_HOSTS" | tr ',' '\n' | grep -q "^$${MCP_REDIRECT_HOST_NO_PORT}$"; then
            NEW_HOSTS="$${NEW_HOSTS},$${MCP_REDIRECT_HOST_NO_PORT}"
        fi

        if ! echo "$NEW_HOSTS" | tr ',' '\n' | grep -q "^$${MCP_REDIRECT_HOST}$"; then
            NEW_HOSTS="$${NEW_HOSTS},$${MCP_REDIRECT_HOST}"
        fi

        # 設定を適用
        ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$TABLEAU_SERVER_SSH_USER@$TABLEAU_SERVER_HOST" \
            "docker exec $TABLEAU_CONTAINER_NAME tsm configuration set -k oauth.allowed_redirect_uri_hosts -v '$NEW_HOSTS' --trust-admin-controller-cert && \
             docker exec $TABLEAU_CONTAINER_NAME tsm pending-changes apply --ignore-prompt --request-timeout 1800 --trust-admin-controller-cert"

        echo "[INFO] OAuth redirect hostを設定しました: $NEW_HOSTS"
    else
        echo "[WARN] SSH秘密鍵が見つかりません: $SSH_KEY_PATH"
        echo "[WARN] Tableau ServerのOAuth設定をスキップしました"
    fi
else
    echo "[INFO] Tableau Server OAuth自動設定は無効です"
fi

#############################################
# フェーズ10: systemdサービス設定
#############################################

echo ""
echo "======================================"
echo "フェーズ10: systemdサービス設定"
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

echo ""
echo "アクセス情報:"
echo "  - MCP Server URL: $MCP_ISSUER/tableau-mcp"
echo "  - OAuth Issuer: $MCP_ISSUER"
echo ""
echo "Claude Desktop設定（settings.json）:"
echo '  {'
echo '    "mcpServers": {'
echo '      "tableau-remote": {'
echo "        \"url\": \"$MCP_ISSUER/tableau-mcp\""
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
