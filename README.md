# Codex 額度狀態列

一個原生 macOS 狀態列 app，讓你快速查看 Codex 5 小時額度剩餘比例與重設倒數；點擊狀態列文字可查看每週、模型專用額度與手動重置額度明細。

## 建置與開啟

需要 macOS 13 或更新版本，以及 Xcode Command Line Tools。

```bash
./scripts/package-app.sh
open "dist/Codex Usage.app"
```

此 app 不顯示 Dock 圖示。面板提供立即刷新，預設每 60 秒更新。

## 登入資料與隱私

App 讀取目前使用者的 `~/.codex/auth.json`，只使用 `tokens.access_token` 與可選的 `tokens.account_id` 查詢額度。請先使用 Codex 登入；app 不會修改或複製登入檔，不會將憑證或查詢結果保存到磁碟，也不會提供消耗手動重置額度的操作。

額度資料來自 `chatgpt.com` 的 `/backend-api/wham/usage` 與 `/backend-api/wham/rate-limit-reset-credits` 唯讀端點。這些是非公開後端介面，服務端可能變更格式或拒絕請求；遇到未提供或無法辨識的資料時，app 會顯示不可用狀態。
