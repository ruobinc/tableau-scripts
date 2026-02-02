#!/bin/bash
#############################################
# Tableau Server 自動セットアップスクリプト
#############################################
# このスクリプトはEC2起動時に自動実行されます
# ログ: /var/log/cloud-init-output.log
#############################################

set -e

# ログ出力設定
exec > >(tee /var/log/tableau-setup.log | logger -t tableau-setup) 2>&1

echo "======================================"
echo "Tableau Server セットアップ開始"
echo "開始時刻: $(date)"
echo "======================================"

#############################################
# Terraformから注入される変数
#############################################

TABLEAU_VERSION="${tableau_version}"
TABLEAU_VERSION_DASHED="${tableau_version_dashed}"
LICENSE_KEY="${license_key}"
TABLEAU_USERNAME="${admin_username}"
TABLEAU_PASSWORD="${admin_password}"
ENABLE_HTTPS="${enable_https}"

# 登録情報
REG_FIRST_NAME="${reg_first_name}"
REG_LAST_NAME="${reg_last_name}"
REG_EMAIL="${reg_email}"
REG_COMPANY="${reg_company}"
REG_TITLE="${reg_title}"
REG_DEPARTMENT="${reg_department}"
REG_PHONE="${reg_phone}"
REG_CITY="${reg_city}"
REG_STATE="${reg_state}"
REG_ZIP="${reg_zip}"
REG_COUNTRY="${reg_country}"
REG_INDUSTRY="${reg_industry}"

# 作業ディレクトリ
WORK_DIR="/home/ec2-user/tableau-container"
DATA_DIR="/home/ec2-user/tableau-data"
SSL_DIR="/home/ec2-user/tableau-ssl"

# コンテナ設定
CONTAINER_NAME="tableau-server"
VOLUME_NAME="tableau-data"

# ダウンロードURL
TABLEAU_SERVER_URL="https://downloads.tableau.com/esdalt/$${TABLEAU_VERSION}/tableau-server-$${TABLEAU_VERSION_DASHED}.x86_64.rpm"
SETUP_TOOLS_URL="https://downloads.tableau.com/esdalt/$${TABLEAU_VERSION}/tableau-server-container-setup-tool-$${TABLEAU_VERSION}.tar.gz"

#############################################
# フェーズ1: システム準備とDocker導入
#############################################

echo ""
echo "======================================"
echo "フェーズ1: システム準備とDocker導入"
echo "======================================"

# システム更新
echo "[INFO] システムを更新しています..."
yum update -y

# Dockerインストール
echo "[INFO] Dockerをインストールしています..."
yum install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Docker動作確認
docker --version
echo "[INFO] Dockerのインストールが完了しました"

#############################################
# フェーズ2: Tableau Serverイメージビルド
#############################################

echo ""
echo "======================================"
echo "フェーズ2: Tableau Serverイメージビルド"
echo "======================================"

# 作業ディレクトリ作成
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Tableau Server RPMダウンロード
echo "[INFO] Tableau Server RPMをダウンロードしています..."
TABLEAU_RPM_FILE=$(basename "$TABLEAU_SERVER_URL")
if [ ! -f "$TABLEAU_RPM_FILE" ]; then
    if ! curl -O --fail --retry 3 --retry-delay 5 "$TABLEAU_SERVER_URL"; then
        echo "[ERROR] Tableau Server RPMのダウンロードに失敗しました"
        echo "[ERROR] URL: $TABLEAU_SERVER_URL"
        exit 1
    fi
fi

# Setup Toolsダウンロード
echo "[INFO] Setup Toolsをダウンロードしています..."
SETUP_TOOLS_FILE=$(basename "$SETUP_TOOLS_URL")
if [ ! -f "$SETUP_TOOLS_FILE" ]; then
    if ! curl -O --fail --retry 3 --retry-delay 5 "$SETUP_TOOLS_URL"; then
        echo "[ERROR] Setup Toolsのダウンロードに失敗しました"
        echo "[ERROR] URL: $SETUP_TOOLS_URL"
        exit 1
    fi
fi

# Setup Tool展開
echo "[INFO] Setup Toolを展開しています..."
tar -xzf "$SETUP_TOOLS_FILE"

SETUP_TOOL_DIR="$WORK_DIR/tableau-server-container-setup-tool-$${TABLEAU_VERSION}"
cd "$SETUP_TOOL_DIR"

# RPMファイルを配置
cp "../$TABLEAU_RPM_FILE" ./

# Dockerイメージビルド
echo "[INFO] Dockerイメージをビルドしています..."
echo "[WARN] ビルドには15-30分程度かかります..."
./build-image --accepteula -i "$TABLEAU_RPM_FILE"

# ビルド結果確認
IMAGE_ID=$(docker images --format "{{.ID}}" | head -1)
echo "[INFO] Dockerイメージのビルドが完了しました: $IMAGE_ID"

# Dockerボリューム作成
echo "[INFO] Dockerボリュームを作成しています..."
docker volume create "$VOLUME_NAME" || true
mkdir -p "$DATA_DIR"

#############################################
# フェーズ3: コンテナ起動・初期化（HTTP）
#############################################

echo ""
echo "======================================"
echo "フェーズ3: コンテナ起動・初期化"
echo "======================================"

# 既存コンテナがあれば削除
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# コンテナ起動（HTTPのみ）
echo "[INFO] Tableau Serverコンテナを起動しています..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --hostname "$CONTAINER_NAME" \
  -p 8080:8080 \
  -v "$${VOLUME_NAME}:/var/opt/tableau" \
  -e LICENSE_KEY="$LICENSE_KEY" \
  -e TABLEAU_USERNAME="$TABLEAU_USERNAME" \
  -e TABLEAU_PASSWORD="$TABLEAU_PASSWORD" \
  "$IMAGE_ID"

echo "[INFO] コンテナを起動しました"

# 基本サービス起動待機
echo "[INFO] 基本サービスの起動を待機しています（2-3分程度）..."
MAX_WAIT=600
WAIT_INTERVAL=15
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "tabadminagent_0 entered RUNNING"; then
        echo "[INFO] 基本サービスが起動しました（所要時間: $${ELAPSED}秒）"
        break
    fi
    echo -n "."
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "[ERROR] 基本サービスの起動がタイムアウトしました"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -50
    exit 1
fi

sleep 10

#############################################
# フェーズ4: ライセンスアクティベーション
#############################################

echo ""
echo "======================================"
echo "フェーズ4: ライセンスアクティベーション"
echo "======================================"

echo "[INFO] ライセンスキーをアクティベートしています..."
docker exec "$CONTAINER_NAME" tsm licenses activate -k "$LICENSE_KEY"
echo "[INFO] ライセンスのアクティベートが完了しました"

# 登録情報ファイル作成
docker exec --user root "$CONTAINER_NAME" mkdir -p /var/opt/tableau/config
docker exec --user root "$CONTAINER_NAME" chown -R tableau:tableau /var/opt/tableau/config

echo "[INFO] 登録情報ファイルを作成しています..."
docker exec "$CONTAINER_NAME" bash -c "cat > /var/opt/tableau/config/reg-info.json << 'EOF'
{
  \"zip\" : \"$${REG_ZIP}\",
  \"country\" : \"$${REG_COUNTRY}\",
  \"city\" : \"$${REG_CITY}\",
  \"last_name\" : \"$${REG_LAST_NAME}\",
  \"industry\" : \"$${REG_INDUSTRY}\",
  \"eula\" : \"yes\",
  \"title\" : \"$${REG_TITLE}\",
  \"phone\" : \"$${REG_PHONE}\",
  \"company\" : \"$${REG_COMPANY}\",
  \"state\" : \"$${REG_STATE}\",
  \"department\" : \"$${REG_DEPARTMENT}\",
  \"first_name\" : \"$${REG_FIRST_NAME}\",
  \"email\" : \"$${REG_EMAIL}\"
}
EOF"

docker exec "$CONTAINER_NAME" tsm register --file /var/opt/tableau/config/reg-info.json
echo "[INFO] 登録情報の適用が完了しました"

#############################################
# フェーズ5: TSM初期化とサーバー起動
#############################################

echo ""
echo "======================================"
echo "フェーズ5: TSM初期化とサーバー起動"
echo "======================================"

echo "[WARN] TSM初期化には10-20分程度かかります..."
docker exec "$CONTAINER_NAME" tsm initialize --start-server --request-timeout 1800
echo "[INFO] TSM初期化とサーバー起動が完了しました"

# ステータス確認
docker exec "$CONTAINER_NAME" tsm status -v

#############################################
# フェーズ5.5: 初期管理者ユーザー作成
#############################################

echo ""
echo "======================================"
echo "フェーズ5.5: 初期管理者ユーザー作成"
echo "======================================"

echo "[INFO] 初期管理者ユーザーを作成しています..."
docker exec "$CONTAINER_NAME" tabcmd initialuser \
    --server "localhost:8080" \
    --username "$TABLEAU_USERNAME" \
    --password "$TABLEAU_PASSWORD"

echo "[INFO] 初期管理者ユーザーの作成が完了しました"
echo "[INFO] ユーザー名: $TABLEAU_USERNAME"

#############################################
# フェーズ6: HTTPS有効化（オプション）
#############################################

if [ "$ENABLE_HTTPS" = "true" ]; then
    echo ""
    echo "======================================"
    echo "フェーズ6: HTTPS有効化"
    echo "======================================"

    # パブリックIP/DNS取得（IMDSv2対応）
    IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
    PUBLIC_DNS=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-hostname)

    echo "[INFO] Public IP: $PUBLIC_IP"
    echo "[INFO] Public DNS: $PUBLIC_DNS"

    # SSL証明書ディレクトリ作成
    mkdir -p "$SSL_DIR"
    cd "$SSL_DIR"

    # SSL証明書生成（自己署名）
    echo "[INFO] SSL証明書を生成しています..."

    # 注意: CNフィールドは64文字制限があるため、IPアドレスを使用
    # AWS Public DNS名は長すぎるためCNには使用不可
    cat > san.cnf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=JP
ST=$${REG_STATE}
L=$${REG_CITY}
O=$${REG_COMPANY}
OU=Tableau
CN=$${PUBLIC_IP}

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $${PUBLIC_IP}
DNS.1 = $${PUBLIC_DNS}
DNS.2 = $${CONTAINER_NAME}
DNS.3 = localhost
EOF

    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr -config san.cnf
    openssl x509 -req -days 365 -in server.csr -signkey server.key \
        -out server.crt -extensions v3_req -extfile san.cnf

    echo "[INFO] SSL証明書の生成が完了しました"

    # 証明書をコンテナに配置
    docker cp "$SSL_DIR/server.crt" "$${CONTAINER_NAME}:/var/opt/tableau/config/server.crt"
    docker cp "$SSL_DIR/server.key" "$${CONTAINER_NAME}:/var/opt/tableau/config/server.key"
    docker exec --user root "$CONTAINER_NAME" chmod 600 /var/opt/tableau/config/server.key
    docker exec --user root "$CONTAINER_NAME" chmod 644 /var/opt/tableau/config/server.crt
    docker exec --user root "$CONTAINER_NAME" chown tableau:tableau /var/opt/tableau/config/server.crt
    docker exec --user root "$CONTAINER_NAME" chown tableau:tableau /var/opt/tableau/config/server.key

    # コンテナ再作成（HTTPSポート追加）
    echo "[INFO] コンテナを再作成してHTTPSポートを追加しています..."
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"

    docker run -d \
        --name "$CONTAINER_NAME" \
        --hostname "$CONTAINER_NAME" \
        -p 8080:8080 \
        -p 443:8443 \
        -v "$${VOLUME_NAME}:/var/opt/tableau" \
        "$IMAGE_ID"

    # サービス起動待機
    echo "[INFO] サービスの起動を待機しています..."
    ELAPSED=0
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "tabadminagent_0 entered RUNNING"; then
            echo "[INFO] 基本サービスが起動しました（所要時間: $${ELAPSED}秒）"
            break
        fi
        echo -n "."
        sleep $WAIT_INTERVAL
        ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    done

    echo "[INFO] 追加で300秒待機します（TSMサービスの完全起動を確保）..."
    sleep 300

    # SSL設定適用
    echo "[INFO] SSL証明書をTSMに登録しています..."
    docker exec "$CONTAINER_NAME" tsm security external-ssl enable \
        --cert-file /var/opt/tableau/config/server.crt \
        --key-file /var/opt/tableau/config/server.key \
        --trust-admin-controller-cert

    docker exec "$CONTAINER_NAME" tsm configuration set -k ssl.enabled -v true --trust-admin-controller-cert
    docker exec "$CONTAINER_NAME" tsm configuration set -k gateway.public.port -v 443 --trust-admin-controller-cert

    echo "[WARN] TSM設定を適用しています（5-10分かかります）..."
    docker exec "$CONTAINER_NAME" tsm pending-changes apply --ignore-prompt --request-timeout 1800 --trust-admin-controller-cert

    echo "[INFO] HTTPS設定が完了しました"
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
echo "  - HTTP:  http://$${PUBLIC_IP}:8080"
if [ "$ENABLE_HTTPS" = "true" ]; then
    echo "  - HTTPS: https://$${PUBLIC_IP}"
fi
echo ""
echo "管理者認証情報:"
echo "  - ユーザー名: $TABLEAU_USERNAME"
echo "  - パスワード: (terraform.tfvarsで設定した値)"
echo ""
echo "コンテナ管理コマンド:"
echo "  - ログ確認: docker logs -f $CONTAINER_NAME"
echo "  - ステータス確認: docker exec $CONTAINER_NAME tsm status -v"
echo ""

# TSMステータス最終確認
docker exec "$CONTAINER_NAME" tsm status -v --trust-admin-controller-cert || true
