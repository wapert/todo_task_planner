# 剩餘步驟 — 待辦計畫 App Store 上架

Status as of build 4. Everything below is what's left; everything not listed
here is done.

---

## ✅ Already done

| Item | Detail |
|---|---|
| App icon | 15 iOS sizes + 1024 marketing, no alpha channel |
| Launch image | App mark at 120/240/360 px |
| Sign in with Apple | Code + entitlement + capability, in signed binary |
| Account deletion | 設定 → 帳號 → 刪除帳號, incl. Apple token revocation |
| Unused permissions | Removed (calendar perms only where the feature exists) |
| Encryption declaration | `ITSAppUsesNonExemptEncryption = false` |
| Bundle ID | `com.wapertech.todoTaskPlanner` across all 4 config sources |
| iOS deployment target | 15.0 (Firebase SPM requires it) |
| Signed IPA | Build 4, Apple Distribution, `UIDeviceFamily = [1,2]` |
| App Store Connect record | Created |
| Screenshots | iPhone 6.9" ×5, iPad 13" ×4, all exact dimensions |
| Listing copy draft | `APP_STORE_LISTING.md` |

---

## 🔲 Step 1 — Upload build 4
Transporter → drag `build/ios/ipa/todo_task_planner.ipa` → **Deliver**.

⚠️ Must be **build 4**. Build 3 was briefly iPhone-only and would reject your
iPad screenshots.

Then wait 10–60 min for processing before the build is selectable.

---

## 🔲 Step 2 — Content you must still produce

These are the only items that need something that doesn't exist yet.

### 2a + 2b. Privacy Policy + Support URLs — **pages written, need publishing**

Following the same pattern as **study_planner** and **fitness-health**:
GitHub Pages serving `docs/`.

Already written for you:
- `docs/privacy.html` — covers email, task content, the **opt-in** calendar
  access, on-device biometric storage, no ads/tracking/selling, and in-app
  account deletion
- `docs/index.html` — support page with contact email + FAQ

**To publish** (this repo has no GitHub remote yet — the other two are under
`github.com/wapert/`):

```bash
cd /Users/macbookair/todo_task_planner
git init && git add -A && git commit -m "Initial commit"
gh repo create wapert/todo_task_planner --private --source=. --push
```

Then GitHub → repo → **Settings → Pages** → Source: `main` branch, `/docs`
folder → Save. Wait ~1 minute, then the URLs are:

| Field | URL |
|---|---|
| **Privacy Policy URL** | `https://wapert.github.io/todo_task_planner/privacy.html` |
| **Support URL** | `https://wapert.github.io/todo_task_planner/` |

> A **private** repo can still serve public Pages on a paid plan; if Pages is
> unavailable, make the repo public — these two files contain nothing secret.
> Note `.gitignore` already excludes build output and `google-services.json`
> style secrets — check `git status` before the first push.

### 2c. Demo account for App Review — **required**

study_planner used this convention, which worked:

```
email:    demo@studyplanner.app
password: demo123456
```

So for this app, create the equivalent via the app's own 註冊 screen:

```
email:    demo@todoplanner.app
password: demo123456
```

- Must be **email/password**, not Google/Apple — a reviewer cannot complete an
  OAuth flow with your credentials.
- Not your personal account.
- After creating it, **add 3–4 tasks** so the reviewer doesn't land on empty
  screens. (I can seed them the same way I did for the screenshots — just ask.)
- Paste the credentials into App Store Connect → App Review Information.

---

## 🔲 Step 3 — Fill in App Store Connect

All copy is drafted in `APP_STORE_LISTING.md` — paste from there.

| Section | Source |
|---|---|
| Name / Subtitle / Promotional text | LISTING §1 |
| Description | LISTING §1 |
| Keywords | LISTING §1 |
| Category (Productivity) | LISTING §1 |
| Screenshots | `~/Desktop/appstore-screenshots/` |
| Support + Privacy URLs | Step 2a / 2b above |
| App Privacy labels | LISTING §3 |
| Age rating questionnaire | LISTING §4 (all None → 4+) |
| App Review demo account + notes | LISTING §5 + Step 2c |

---

## 🔲 Step 4 — TestFlight testing (do not skip)

Three flows have **never been executed even once**. Two of them are things
reviewers check directly.

- [ ] **Sign in with Apple** — never run. Failed on Simulator only because it
      has no iCloud account; needs a real device.
- [ ] **刪除帳號 end-to-end** — never run. Use a throwaway account. Confirm the
      account is gone *and* the Firestore data disappeared.
- [ ] Google sign-in on a real iPhone
- [ ] Apple 行事曆 sync — grants the OS calendar prompt and writes events
- [ ] Google 日曆 sync
- [ ] Firestore sync across two devices
- [ ] Biometric (Face ID) login

---

## 🔲 Step 5 — Submit for Review
Typically 24–48 h for a first review.

---

## 🧹 Housekeeping (optional)

- **7 seeded demo tasks** are live in your Google account and syncing to your
  phone (完成專案簡報, 回覆客戶郵件, 健身房訓練, 團隊週會, 整理季度報表,
  採買日用品, 閱讀 30 分鐘). Say the word and they get deleted.
- **Old iOS Firebase app** (`…ios:e153aa…`, old bundle ID) is dead but still
  registered — worth removing to avoid confusion.
- **macOS keychain sign-in bug** — diagnosed (`errSecMissingEntitlement`,
  needs `keychain-access-groups` + team signing), not fixed. macOS isn't being
  shipped, so this only matters if you want the Mac build working.
- **CocoaPods** can be removed from `ios/` — all plugins are Swift Packages
  now, which would speed up builds.
- **Android** still uses bundle ID `com.todo.taskplanner.todo_task_planner`
  and is unaffected by any of the iOS renaming.
