# App Store 上架素材草稿 — 待辦計畫

Draft copy to paste into App Store Connect. Edit freely — the wording is a
starting point, not a prescription. Character limits are Apple's.

---

## 1. App 資訊

| Field | Value | Limit |
|---|---|---|
| **App Name** | `待辦計畫` | 30 |
| **Subtitle** | `每日任務 · 週計畫 · 進度追蹤` | 30 |
| **Primary language** | 繁體中文 | — |
| **Category (primary)** | Productivity 生產力工具 | — |
| **Category (secondary)** | Utilities 工具程式 | — |
| **Copyright** | `2026 Wapertech` | — |

### Promotional text (≤170, editable without a new build)
```
用「今日」專注當天該做的事，用「週計畫」安排整週節奏，再用「進度」看見自己的完成率。跨裝置同步，換手機也不怕資料不見。
```

### Keywords (≤100 chars total, comma-separated, no spaces after commas)
```
待辦,任務,計畫,週計畫,行事曆,提醒,清單,生產力,時間管理,todo,task,planner
```
> Don't repeat words already in the app name or subtitle — Apple indexes those
> separately, so reusing them wastes the 100 characters.

### Description (≤4000)
```
「待辦計畫」是一款專注、乾淨的待辦事項與週計畫工具，幫你把「今天要做什麼」和「這週要完成什麼」分開管理。

■ 四個頁面，剛好夠用
・今日 — 只顯示當天任務，並可左右切換到其他日期
・行事曆 — 月曆檢視，有任務的日子一眼看得出來
・週計畫 — 一次看完整週七天，直接安排任務落在哪一天
・進度 — 以「本週／本月／自訂區間」統計完成率與待辦分佈

■ 跨裝置同步
登入後任務自動同步到雲端，換裝置、重裝 App 資料都還在。

■ 多種登入方式
支援 Apple 帳號、Google 帳號與電子郵件註冊登入，並可啟用 Face ID／Touch ID 快速登入。

■ 行事曆整合（選用）
以 Apple 或 Google 帳號登入時，可將任務同步為行事曆事件，和既有行程一起檢視。此功能完全選用，不同步也不影響任何功能。

■ 隱私
任務資料只屬於你，僅你本人的帳號能存取。App 不含廣告、不做使用者追蹤。你可以隨時在「設定」中永久刪除帳號與所有資料。
```

---

## 2. URLs — 兩個都是必填

| Field | Required | Notes |
|---|---|---|
| **Support URL** | ✅ Yes | A page with a contact email is enough |
| **Privacy Policy URL** | ✅ Yes | Mandatory — the app has accounts and collects data |
| Marketing URL | Optional | |

The privacy policy **must** disclose: email address, task content, Firebase
user ID, and (if the user opts in) calendar access.

---

## 3. App Privacy — 隱私標籤

App Store Connect → App Privacy. Answers for this app:

**Do you collect data? → Yes**

| Data type | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| Contact Info → Email Address | Yes | Yes | **No** | App Functionality |
| User Content → Other User Content (tasks) | Yes | Yes | **No** | App Functionality |
| Identifiers → User ID (Firebase UID) | Yes | Yes | **No** | App Functionality |

**Tracking question → No.** No ads, no analytics SDK, no data brokers, nothing
shared with third parties for advertising.

> Calendar data is *written to*, never collected or transmitted to us — it
> stays on the device / in the user's own calendar account, so it is not
> declared as collected data.

---

## 4. Age Rating
Run the questionnaire; every answer is **None / No** for this app. Expected
result: **4+**.

---

## 5. App Review Information — 必填

Review is behind a login wall, so this is not optional.

| Field | Value |
|---|---|
| Sign-in required | **Yes** |
| Demo account | *(create a throwaway email/password account)* |
| Demo password | *(…)* |

**Use an email/password account, not Google or Apple** — a reviewer can't
easily complete a third-party OAuth flow with your credentials.

### Notes for the reviewer (paste into the Notes field)
```
The app interface is in Traditional Chinese.

Sign-in: please use the demo email/password account provided above.
Sign in with Apple and Google sign-in are also supported.

Calendar permission: the app only requests calendar access if the user
explicitly taps the calendar sync option in Settings (設定). It is entirely
optional and the app is fully functional without granting it.

Account deletion: 設定 → 帳號 → 刪除帳號. This permanently deletes the account
and all associated data, as required by guideline 5.1.1(v).

Biometric login (Face ID) is optional and can be enabled in Settings.
```

---

## 6. Screenshots — 兩種尺寸都必填

App targets iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = 1,2`), so both are
required.

| Device | Pixels | Simulator on this Mac |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | iPhone 17 Pro Max |
| iPad 13" | 2064 × 2752 | iPad Pro 13-inch (M5) |

Capture with a few sample tasks in place — never an empty state, never real
personal data:

```bash
xcrun simctl io booted screenshot ~/Desktop/shot-01-today.png
```

Suggested order: 今日 → 週計畫 → 行事曆 → 進度 → 設定
