# 密碼修改說明

## 啟動前

需要改三個地方，三個**密碼必須完全一致**（都是 `wazuh-wui` 這組帳號）：

```yaml
# docker-compose.yml 第 36 行（wazuh.manager）
API_PASSWORD=你自己的密碼

# docker-compose.yml 第 106 行（wazuh.dashboard）
API_PASSWORD=你自己的密碼
```

```yaml
# config/wazuh_dashboard/wazuh.yml 第 6 行
password: "你自己的密碼"
```

原本三個都是 `MyS3cr37P450r.*-`，GitHub 公開必改。

`SecretPassword` 和 `kibanaserver` 先不動，讓系統用預設值啟動。

---

## 啟動後

### 1. 登入 Dashboard

```
網址：https://你的ServerIP
帳號：admin
密碼：SecretPassword
```

### 2. 改 admin 密碼（可透過 UI）

```
右上角頭像 → Security → Internal Users → 點 admin → 改密碼
```

直接輸入新密碼儲存即可，系統會自動處理 hash。

### 3. 改 kibanaserver 密碼（UI 無法改，要走設定檔）

`kibanaserver` 是系統保留帳號（`reserved: true`），UI 上看不到密碼欄位可改，必須手動產生新的 bcrypt hash：

```bash
# 進 indexer 容器產生 hash
docker exec -it wazuh-single-node-wazuh.indexer-1 \
  bash -c "python3 -c \"import bcrypt; print(bcrypt.hashpw(b'你的新密碼', bcrypt.gensalt(12)).decode())\""
```

把輸出的 hash 貼進 `config/wazuh_indexer/internal_users.yml`：

```yaml
kibanaserver:
  hash: "貼上產生的hash"
  reserved: true
```

### 4. 同步更新 docker-compose.yml

```yaml
INDEXER_PASSWORD=你剛在UI改的admin密碼
DASHBOARD_PASSWORD=你剛產生hash對應的kibanaserver密碼
```

### 5. 重啟讓新密碼生效

```bash
docker compose down && docker compose up -d
```

---

## 密碼對應總覽

| 帳號 | 用途 | 改法 |
|------|------|------|
| `admin` | Indexer 管理員，Manager/Dashboard 連線用 | Dashboard UI 可直接改 → 同步 `INDEXER_PASSWORD` |
| `kibanaserver` | Dashboard 內部連 Indexer 用 | UI 無法改（reserved 帳號）→ 手動產生 hash 改設定檔 → 同步 `DASHBOARD_PASSWORD` |
| `wazuh-wui` | Wazuh API 帳號 | 只改 `docker-compose.yml` 和 `wazuh.yml` 的 `API_PASSWORD` |
