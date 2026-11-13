# Codex 額度狀態列 App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立原生 macOS 狀態列 app，顯示 Codex 5 小時額度剩餘比例，並在點擊後呈現額度與重設明細。

**Architecture:** Swift Package Manager 提供單一 macOS executable target；SwiftUI `MenuBarExtra` 作為狀態列入口。認證讀取、Codex API、回應模型、刷新狀態與 UI 分層，最後以腳本包裝為可直接開啟的 `.app`。

**Tech Stack:** Swift 5.9+, Swift Package Manager, SwiftUI `MenuBarExtra`, Foundation `URLSession`; macOS 13.0 以上。

**Spec:** `docs/superpowers/specs/2026-11-13-codex-usage-menu-bar-design.md`

## Global Constraints

- 以原生 SwiftUI `MenuBarExtra` 建立 macOS 狀態列 app，不顯示 Dock 圖示。
- 只有 `primary_window.limit_window_seconds == 18,000` 時，才將狀態列數值標示為 5 小時額度。
- 啟動時立即查詢、每 60 秒自動刷新，並提供面板手動刷新。
- 只讀取 `~/.codex/auth.json` 的 `tokens.access_token` 與可選 `tokens.account_id`，只呼叫設計文件列出的兩個唯讀 GET 端點。
- 不修改或複製登入檔、不保存憑證或查詢資料、不加入遙測、不顯示或記錄敏感憑證、不提供額度消耗操作。
- 使用額度與手動重置額度各自維護最後成功時間；部分失敗時保留並標示各自的舊資料。
- `/wham` 是非公開介面；缺少、無效或未預期的欄位必須以未知／不可用狀態呈現，不得推算或崩潰。

## Review Focus

- `~/.codex/auth.json` 缺少、格式錯誤或沒有 `tokens.access_token` 時，顯示可理解的登入錯誤，不送出 API 請求。
- API 回傳 401 或錯誤訊息含授權內容時，顯示安全錯誤，不能洩漏 access token 或 account ID。
- `primary_window` 時長缺漏或不是 18,000 秒時，狀態列必須顯示 `5h --`，不可把其他視窗當成 5 小時額度。
- 兩個端點其中一個刷新失敗時，另一區仍更新；失敗區保留舊資料並標明該區最後成功時間。
- 額外模型欄位、重置額度清單缺少或格式改變時，面板需正常顯示已知資料與不可用提示。

---

### Task 1: Create the SwiftPM macOS menu bar app shell

**Files:**
- Create: `Package.swift`
- Create: `Sources/CodexUsageMenuBar/App/CodexUsageMenuBarApp.swift`
- Create: `Sources/CodexUsageMenuBar/UI/MenuBarContentView.swift`
- Create: `Resources/AppInfo.plist`
- Create: `scripts/package-app.sh`

**Interfaces:**
- Produces executable target `CodexUsageMenuBar` and app bundle `dist/Codex Usage.app`.
- Entry point is `CodexUsageMenuBarApp`; initial menu title is `5h --` until data wiring is added.

- [ ] **Step 1: Define the SwiftPM executable target**

Create a macOS executable package with no third-party dependencies and deployment target macOS 13.0. Name the executable `CodexUsageMenuBar`.

- [ ] **Step 2: Add a menu bar only SwiftUI scene**

Implement `CodexUsageMenuBarApp` using `MenuBarExtra` with `.window` style and a placeholder `MenuBarContentView`. Set `LSUIElement` to `true` in `Resources/AppInfo.plist` so the app does not show a Dock icon.

- [ ] **Step 3: Package the executable as a `.app` bundle**

Implement `scripts/package-app.sh` to run a release build, create `dist/Codex Usage.app/Contents/MacOS`, copy the executable, and install the Info.plist with bundle ID `com.nickycho.CodexUsageMenuBar` and executable name `CodexUsageMenuBar`.

- [ ] **Step 4: Build and package the shell**

Run `swift build --configuration release` and `scripts/package-app.sh`. Expected: both commands succeed and `dist/Codex Usage.app/Contents/MacOS/CodexUsageMenuBar` exists.

### Task 2: Add credentials, API client, and response models

**Files:**
- Create: `Sources/CodexUsageMenuBar/Domain/UsageModels.swift`
- Create: `Sources/CodexUsageMenuBar/Services/CodexAuthFileReader.swift`
- Create: `Sources/CodexUsageMenuBar/Services/CodexUsageAPIClient.swift`

**Interfaces:**
- `CodexCredentials`: `accessToken: String`, `accountID: String?`.
- `CodexAuthFileReader.loadCredentials() throws -> CodexCredentials`.
- `CodexUsageAPIClient.fetchUsage(credentials:) async throws -> UsageResponse`.
- `CodexUsageAPIClient.fetchResetCredits(credentials:) async throws -> ResetCreditsResponse`.
- `UsageResponse` contains the optional plan type, primary and secondary `UsageWindow`, and returned `AdditionalRateLimit` values.
- `UsageWindow` contains optional `usedPercent`, `limitWindowSeconds`, `resetAfterSeconds`, and `resetAt` values.
- `ResetCreditsResponse` contains optional `availableCount` and optional `[ResetCredit]`; `nil` means no recognizable list was returned, while an empty list means the API explicitly returned no credits. Each credit contains optional status, granted time, and expiry time.

- [ ] **Step 1: Define decodable domain response types**

Add the interfaces above with optional fields for data the API may omit. Keep raw bearer credentials out of all response and display models.

- [ ] **Step 2: Read Codex credentials from the default auth file**

Resolve `~/.codex/auth.json` from the current user's home directory, parse only `tokens.access_token` and `tokens.account_id`, and throw a typed safe error for missing file, invalid JSON, or absent access token.

- [ ] **Step 3: Implement the two read only API requests**

Use `URLSession` with a 15 second request timeout. Send `OpenAI-Beta: codex-1` and `originator: Codex Desktop`; add `ChatGPT-Account-ID` only when present. Decode `/backend-api/wham/usage` and `/backend-api/wham/rate-limit-reset-credits`. Sanitize failure messages before returning them to UI state.

- [ ] **Step 4: Normalize response shape variants used by the reference**

Accept credit arrays under `credits`, `items`, or `data` and optional additional rate limit windows. Preserve only understood fields; leave missing values unavailable instead of inventing defaults.

- [ ] **Step 5: Build the package**

Run `swift build`. Expected: the new domain and service files compile without third party dependencies.

### Task 3: Implement refresh state and partial failure handling

**Files:**
- Create: `Sources/CodexUsageMenuBar/State/UsageViewModel.swift`
- Modify: `Sources/CodexUsageMenuBar/App/CodexUsageMenuBarApp.swift`

**Interfaces:**
- `@MainActor final class UsageViewModel: ObservableObject` publishes `UsagePanelState` and provides `func refresh() async`.
- `UsagePanelState` holds usage and reset credits independently, each with its own last successful update time and optional safe error.
- `UsageViewModel.menuBarTitle` returns `5h <remaining>%` only for a valid 18,000 second primary window; otherwise it returns `5h --`.

- [ ] **Step 1: Define view model state for independent API results**

Represent initial loading, usage result, reset credits result, per-source update timestamps, and per-source safe errors. Keep successful values in memory only.

- [ ] **Step 2: Fetch both sources without coupling their success**

Implement `refresh()` to load credentials once, then request usage and reset credits concurrently. Apply each successful result even if the other request fails; on failure retain that source's last successful value and timestamp.

- [ ] **Step 3: Derive the status bar summary conservatively**

Require `primary_window.limit_window_seconds == 18_000` and finite `used_percent` before calculating `100 - used_percent`; clamp the displayed result to 0–100. Otherwise return `5h --`.

- [ ] **Step 4: Add startup, periodic, and manual refresh behavior**

Trigger `refresh()` when the app starts and every 60 seconds. Prevent overlapping requests; manual refresh uses the same guarded operation and updates the two per-source timestamps independently.

- [ ] **Step 5: Build the package**

Run `swift build`. Expected: view model and app composition compile.

### Task 4: Complete the status summary, details panel, and app instructions

**Files:**
- Modify: `Sources/CodexUsageMenuBar/App/CodexUsageMenuBarApp.swift`
- Modify: `Sources/CodexUsageMenuBar/UI/MenuBarContentView.swift`
- Create: `Sources/CodexUsageMenuBar/UI/UsageWindowRow.swift`
- Create: `Sources/CodexUsageMenuBar/UI/ResetCreditsSection.swift`
- Create: `README.md`

**Interfaces:**
- `MenuBarContentView` consumes `UsageViewModel` and renders all status states.
- `UsageWindowRow` renders a labeled percentage and reset countdown for one window.
- `ResetCreditsSection` renders available count and each returned credit's status, grant time, and expiry.

- [ ] **Step 1: Wire the live status bar title and startup refresh**

Pass the shared `UsageViewModel` to the `MenuBarExtra` label and detail view. Show the derived `5h XX%` or `5h --` title and start the refresh lifecycle once.

- [ ] **Step 2: Render full quota details in the popover**

Display 5-hour primary, weekly secondary, each returned model-specific window, reset countdowns, reset credit count and records, and last updated times. Use local time for timestamps and text labels in addition to color.

- [ ] **Step 3: Render loading, missing-auth, stale, and refresh errors**

Show an immediate-refresh button. Keep each API section's last successful values on partial failure and show that section's safe error and timestamp. Do not show raw JSON or credentials.

- [ ] **Step 4: Document launch, data access, and known endpoint limitation**

Add Traditional Chinese README instructions for `scripts/package-app.sh`, opening `dist/Codex Usage.app`, required `~/.codex/auth.json`, the read-only data flow, and the non-public `/wham` endpoint limitation.

- [ ] **Step 5: Build and create the final app bundle**

Run `scripts/package-app.sh`. Expected: release build succeeds and produces `dist/Codex Usage.app` with `LSUIElement` enabled and the `CodexUsageMenuBar` executable inside.

## Self-Review

- **Spec coverage:** Menu bar only app and status summary are Tasks 1 and 4; auth, read-only endpoints, normalization and redaction are Task 2; refresh lifecycle and partial failures are Task 3; detail fields and instructions are Task 4.
- **Step scan:** Each step creates one package layer or produces one buildable deliverable; interfaces are stated above their consumers.
- **Type consistency:** API returns `UsageResponse` and `ResetCreditsResponse`; the view model stores both independently in `UsagePanelState`; UI consumes the shared `UsageViewModel`.
- **Review focus:** The five risk cases are listed above; response handling, per-source state, and the conservative 5-hour calculation own them.
- **Proportion:** Four tasks follow the package-to-UI dependency order, with no third-party framework or separate service.
