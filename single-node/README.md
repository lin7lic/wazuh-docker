# Wazuh Docker 設定（4.14.6-rc1）

基於官方 single-node 加入自訂通報與規則。

## 目錄結構

```
single-node/
├── .env                              # 官方原版（版本號）
├── docker-compose.yml                # 官方原版 + port 綁定修改
├── generate-indexer-certs.yml        # 官方原版（產生 SSL 憑證用）
└── config/
    ├── certs.yml                     # 官方原版（憑證設定）
    ├── wazuh_cluster/
    │   ├── wazuh_manager.conf        # 官方原版 + 自訂通報設定
    │   ├── local_rules.xml           # 【自訂】偵測規則
    │   └── telegram-notify.sh        # 【自訂】Telegram 通知 script
    ├── wazuh_indexer/
    │   ├── wazuh.indexer.yml         # 官方原版
    │   └── internal_users.yml        # 官方原版
    └── wazuh_dashboard/
        ├── opensearch_dashboards.yml # 官方原版
        └── wazuh.yml                 # 官方原版
```

---

## 初始化步驟

### 1. 填入 Telegram 資訊
```bash
nano config/wazuh_cluster/telegram-notify.sh
# 填入 BOT_TOKEN 和 CHAT_ID
```

### 2. 加入白名單（避免封鎖自己）
```bash
nano config/wazuh_cluster/wazuh_manager.conf
# 找到 <white_list> 區塊，加入你的管理 IP
```

### 3. 調整 port 綁定（建議）
```bash
nano docker-compose.yml
# 把 1514/1515 改成只允許你的內網網段
# 把 443 改成你的管理 IP
```

### 4. 產生 SSL 憑證
```bash
docker compose -f generate-indexer-certs.yml run --rm generator
```

### 5. 啟動
```bash
docker compose up -d
```

### 6. 確認 telegram script 權限
```bash
docker exec $(docker compose ps -q wazuh.manager) \
  chmod +x /var/ossec/active-response/bin/telegram-notify.sh
```

---

## 修改設定後重啟

```bash
# 語法檢查（重啟前先確認）
docker exec $(docker compose ps -q wazuh.manager) \
  /var/ossec/bin/ossec-logtest -t

# 重啟 Manager（Indexer 和 Dashboard 不用動）
docker compose restart wazuh.manager

# 看是否正常啟動
docker compose logs wazuh.manager | tail -20
```

---

## 手動封鎖 IP（收到 Telegram 通報後）

- 修改密碼 `MyS3cr37P450r.*-`
```bash
# 查 Agent ID
curl -u wazuh-wui:'MyS3cr37P450r.*-' -k \
  "https://localhost:55000/agents?pretty=true"

# 封鎖（暫時，timeout 後自動解封）
curl -u wazuh-wui:'MyS3cr37P450r.*-' -k -X PUT \
  "https://localhost:55000/active-response?agents_list=001" \
  -H "Content-Type: application/json" \
  -d '{"command":"firewall-drop0","arguments":["-","null","惡意IP","null"]}'

# 多台同時封鎖
# ?agents_list=001,002,003
```

---

## 各檔案修改說明

| 檔案 | 來源 | 修改內容 |
|------|------|----------|
| `docker-compose.yml` | 官方修改 | port 綁定 IP 限制、加入 3 個 bind mount |
| `wazuh_manager.conf` | 官方修改 | log_alert_level 改為 8、加入 telegram command 和 active-response |
| `local_rules.xml` | 新增 | 登入/暴力破解/FIM/rootkit 偵測規則 |
| `telegram-notify.sh` | 新增 | Telegram 通知 + 冷卻機制 |
| 其餘所有檔案 | 官方原版 | 未修改 |

---

## 常用指令

```bash
docker compose ps                          # 查看容器狀態
docker compose logs -f wazuh.manager      # 即時日誌
docker compose restart wazuh.manager      # 重啟 Manager
docker compose down                        # 停止（資料保留）
docker compose down -v                     # 停止並刪除所有資料（危險）
```

---

## 升級版本

版本號統一在 `.env` 控制，三個容器會一起升級：

```bash
# 1. 修改 .env 裡的版本號
nano .env
# WAZUH_IMAGE_VERSION=4.14.7  ← 改這行

# 2. 拉新版並重啟
docker compose pull && docker compose up -d
```

資料存在 named volume，升級不會遺失。
