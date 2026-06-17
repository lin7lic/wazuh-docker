# 密碼修改說明

## 啟動前

只需要改 `docker-compose.yml` 裡的一個地方：

```yaml
API_PASSWORD=你自己的密碼    # 原本是 MyS3cr37P450r.*-，GitHub 公開必改
```

`SecretPassword` 和 `kibanaserver` 先不動，讓系統用預設值啟動。

---

## 啟動後

### 1. 登入 Dashboard

```
網址：https://你的ServerIP
帳號：admin
密碼：SecretPassword
```

### 2. 進入密碼管理頁面

```
右上角頭像 → Security → Internal Users
```

### 3. 改這兩個帳號的密碼

- `admin`（Indexer 管理員）
- `kibanaserver`（Dashboard 連 Indexer 用）

點進去直接輸入新密碼儲存即可，系統會自動處理 hash。

### 4. 同步更新 docker-compose.yml

```yaml
INDEXER_PASSWORD=你剛改的admin密碼
DASHBOARD_PASSWORD=你剛改的kibanaserver密碼
```

### 5. 重啟讓新密碼生效

```bash
docker compose down && docker compose up -d
```

---

## 密碼對應總覽

| 帳號 | 用途 | 改法 |
|------|------|------|
| `admin` | Indexer 管理員，Manager/Dashboard 連線用 | Dashboard UI 改 → 同步 `INDEXER_PASSWORD` |
| `kibanaserver` | Dashboard 內部連 Indexer 用 | Dashboard UI 改 → 同步 `DASHBOARD_PASSWORD` |
| `wazuh-wui` | Wazuh API 帳號 | 只改 `docker-compose.yml` 的 `API_PASSWORD` |
