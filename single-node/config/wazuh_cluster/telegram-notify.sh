#!/bin/bash
# Wazuh Telegram 通知 Script
# 掛載路徑：/var/ossec/active-response/bin/telegram-notify.sh
# 啟動後需確認權限：docker exec <manager> chmod +x /var/ossec/active-response/bin/telegram-notify.sh

# ==========================================
# 【必填】修改這裡
# ==========================================
BOT_TOKEN="你的BOT_TOKEN"
CHAT_ID="你的CHAT_ID"

# 同一來源 IP 冷卻時間（秒）
# 同個 IP 在此時間內只送一次，避免爆量
COOLDOWN_SEC=300

# ==========================================
# 冷卻機制
# ==========================================
COOLDOWN_DIR="/tmp/wazuh-tg-cooldown"
mkdir -p "$COOLDOWN_DIR"

# 讀取 Wazuh 傳入的 JSON 警報
read INPUT_JSON

# 解析欄位
parse_field() {
  echo "$INPUT_JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    keys = '$1'.split('.')
    v = d
    for k in keys:
        v = v.get(k, {}) if isinstance(v, dict) else ''
    print(v if v != {} else '')
except:
    print('')
"
}

ALERT_LEVEL=$(parse_field "rule.level")
ALERT_DESC=$(parse_field "rule.description")
AGENT_NAME=$(parse_field "agent.name")
AGENT_IP=$(parse_field "agent.ip")
TIMESTAMP=$(parse_field "timestamp")
SRCIP=$(parse_field "data.srcip")
DSTUSER=$(parse_field "data.dstuser")
FULL_LOG=$(parse_field "full_log")

# 冷卻檢查（以來源 IP 為 key）
if [ -n "$SRCIP" ] && [ "$SRCIP" != "None" ]; then
  LOCK_KEY=$(echo "$SRCIP" | tr '.' '_' | tr '/' '_')
  LOCK_FILE="$COOLDOWN_DIR/${LOCK_KEY}"
  if [ -f "$LOCK_FILE" ]; then
    LAST=$(cat "$LOCK_FILE")
    NOW=$(date +%s)
    DIFF=$((NOW - LAST))
    if [ "$DIFF" -lt "$COOLDOWN_SEC" ]; then
      exit 0  # 冷卻中，不送
    fi
  fi
  date +%s > "$LOCK_FILE"
fi

# ==========================================
# 組裝訊息
# ==========================================

# 依等級設定 emoji
if [ "$ALERT_LEVEL" -ge 15 ] 2>/dev/null; then
  LEVEL_EMOJI="🚨"
elif [ "$ALERT_LEVEL" -ge 12 ] 2>/dev/null; then
  LEVEL_EMOJI="⛔"
elif [ "$ALERT_LEVEL" -ge 8 ] 2>/dev/null; then
  LEVEL_EMOJI="⚠️"
else
  LEVEL_EMOJI="ℹ️"
fi

SRC_LINE=""
if [ -n "$SRCIP" ] && [ "$SRCIP" != "None" ]; then
  SRC_LINE="
🌐 *來源 IP*：\`${SRCIP}\`"
fi

USER_LINE=""
if [ -n "$DSTUSER" ] && [ "$DSTUSER" != "None" ]; then
  USER_LINE="
👤 *使用者*：${DSTUSER}"
fi

# 日誌太長就截斷
if [ ${#FULL_LOG} -gt 300 ]; then
  FULL_LOG="${FULL_LOG:0:300}..."
fi

MESSAGE="${LEVEL_EMOJI} *Wazuh 警報*
━━━━━━━━━━━━━━
📋 *事件*：${ALERT_DESC}
⚠️ *等級*：${ALERT_LEVEL}
🖥️ *主機*：${AGENT_NAME} \(${AGENT_IP}\)${SRC_LINE}${USER_LINE}
🕐 *時間*：${TIMESTAMP}

📄 *日誌*：
\`${FULL_LOG}\`"

# ==========================================
# 送出通知
# ==========================================
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  --max-time 10 \
  -d chat_id="${CHAT_ID}" \
  -d parse_mode="Markdown" \
  -d text="${MESSAGE}" \
  > /dev/null 2>&1

exit 0
