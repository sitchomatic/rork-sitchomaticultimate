# Unified Sessions: 10 screenshots per credential + auto cookie dismissal

## Changes

### 1. Screenshot limit — 10 per credential (5 per site)

- Update the screenshot options in Unified Sessions to support up to **10 screenshots per credential** (5 per site)
- Add new options: `five` (5 total), `six` (6 total), `eight` (8 total), `ten` (10 total) to the picker
- Default changes from 3 to **10**
- The priority pruning will keep 5 screenshots per site maximum

### 2. Smart reduction — 2 screenshots on clear result

- When a **clear/definitive result** is detected (success, perm disabled, temp disabled), the system automatically reduces to **2 screenshots total** (1 per site) — keeping only the terminal/crucial screenshot for each site
- All intermediate post-click screenshots for that credential get purged when a clear result is found
- This saves memory while keeping proof of the decisive outcome

### 3. Auto-dismiss cookie notices app-wide

- Cookie notices will be **automatically dismissed** on both Joe and Ignition sites right after page load in the Unified Sessions worker — before typing begins
- The cookie dismiss toggle in settings will be **forced to ON** and the toggle will show as always enabled (non-interactive) in the Unified Sessions settings
- Cookie dismissal runs in parallel on both sites for speed

### Files Changed

- **AutomationSettings** — New enum cases for `UnifiedScreenshotCount` (5, 6, 8, 10), default to 10
- **DualSiteWorkerService** — Add cookie dismissal after page load, update screenshot pruning logic to smart-reduce to 2 on clear results
- **UnifiedScreenshotManager** — Add `smartReduceForClearResult()` method that keeps only 1 screenshot per site
- **UnifiedSessionSettingsView** — Updated picker options, cookie toggle shown as always-on

