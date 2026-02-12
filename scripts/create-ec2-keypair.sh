#!/bin/bash
#############################################
# EC2キーペア作成スクリプト
# 使用例: ./scripts/create-ec2-keypair.sh my-key-name [出力先]
# リージョンはAWS CLI設定から自動取得
#############################################

set -e

KEY_NAME="${1:-tableau-server-key}"
OUTPUT_DIR="${2:-../.aws}"

# リージョンをAWS CLI設定から取得（AWS_DEFAULT_REGION → プロファイル設定 → フォールバック）
REGION="${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo "us-east-1")}"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}EC2キーペア作成スクリプト${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "キー名:     $KEY_NAME"
echo "リージョン: $REGION"
echo "出力先:     $OUTPUT_DIR/"
echo ""

# 出力ディレクトリ作成
mkdir -p "$OUTPUT_DIR"

# 既存キーの確認
PEM_FILE="$OUTPUT_DIR/$KEY_NAME.pem"
if [ -f "$PEM_FILE" ]; then
    echo -e "${RED}エラー: $PEM_FILE は既に存在します${NC}"
    echo "削除する場合: rm $PEM_FILE"
    exit 1
fi

# AWSにキーペアが存在するか確認
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}警告: キーペア '$KEY_NAME' はAWSに既に存在します${NC}"
    echo ""
    echo "選択肢:"
    echo "  1) 既存のキーを使用（秘密鍵が手元にある場合）"
    echo "  2) 削除して再作成"
    echo ""
    read -p "選択 [1/2]: " choice

    if [ "$choice" = "2" ]; then
        echo "既存キーペアを削除中..."
        aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"
        echo -e "${GREEN}削除完了${NC}"
    else
        echo "処理を中止します。"
        exit 0
    fi
fi

# キーペア作成
echo "キーペアを作成中..."
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query 'KeyMaterial' \
    --output text > "$PEM_FILE"

# パーミッション設定
chmod 600 "$PEM_FILE"

echo ""
echo -e "${GREEN}✓ キーペア作成完了！${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "秘密鍵: $PEM_FILE"
echo ""
echo "SSH接続例:"
echo "  ssh -i $PEM_FILE ec2-user@<インスタンスIP>"
