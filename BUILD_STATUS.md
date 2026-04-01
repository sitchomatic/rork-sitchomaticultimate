# iOS Build Status Report

## Current Status
**Status:** ❌ FAILING
**Last Successful Build:** Unknown (all recent builds failing)
**Build Workflow:** `.github/workflows/ios-build.yml`
**Latest Failed Run:** #58 (commit e55dc87)

## Build Environment
- **Runner:** macOS-15
- **Xcode Version:** 16.2
- **Swift Version:** 6.0.x
- **SDK:** iOS Simulator 18.2

## Recent Build Failures

All builds from #51 through #58 have failed, indicating a systemic issue:

1. **Run #58** (main branch) - FAILURE
   - Commit: e55dc872 "Align ZIPFoundation dependency to resolvable tag to unblock builds"
   - Build time: ~50 seconds before failure

2. **Run #57, #56, #55** (various PRs) - FAILURE
   - All attempting to fix ZIPFoundation and XMLCoder dependency issues

3. **Run #54** (main branch) - FAILURE
   - Commit: 6ae49ff7 "Resolve XMLCoder module lookup for CoreXLSX build"

## Known Issues From Repository History

Based on repository memories and recent PR titles, the following issues are known:

### 1. Dependency Version Conflicts
- ZIPFoundation dependency was set to 0.10.0 but no such version exists
- Fixed in PR #49 by downgrading to 0.9.20
- However, builds still failing after this fix

### 2. Swift Package Module Resolution
- XMLCoder module lookup issues for CoreXLSX
- Attempted fix in PR #44 using `$(BUILD_DIR)/../../SourcePackages/...` paths

### 3. Swift Concurrency Issues
- Swift 6.0.x on Xcode 16.2 does not support `nonisolated` on type declarations
- Requires Swift 6.2 (SE-0466) or `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- Actor isolation violations in NetworkSessionFactory (fixed in PR #43)

## Build Configuration

From `.github/workflows/ios-build.yml`:
- Building 4 targets: Sitchomatic, SitchomaticWidget, SitchomaticTests, SitchomaticUITests
- Configuration: Release
- Code signing: DISABLED (`CODE_SIGNING_ALLOWED=NO`)
- Warnings as errors: DISABLED for both Swift and Clang

## Dependencies
- CoreXLSX (SwiftPM package)
- XMLCoder (SwiftPM package)
- ZIPFoundation (SwiftPM package, version 0.9.20)

## Root Cause Identified

**Issue:** Stale `SWIFT_INCLUDE_PATHS` override in Xcode project configuration

**Location:** `ios/Sitchomatic.xcodeproj/project.pbxproj` (lines 441 and 498)

```
SWIFT_INCLUDE_PATHS = "$(inherited) $(BUILD_DIR)/../../SourcePackages/checkouts/XMLCoder/build/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)";
```

**Problem:**
- This manual path override for XMLCoder module lookup is conflicting with SwiftPM's automatic module resolution
- SwiftPM automatically manages module paths for all dependencies (ZIPFoundation, XMLCoder, CoreXLSX)
- The hardcoded path was likely added to work around a previous build issue (see PR #44) but is now causing module resolution failures
- Modern Xcode/SwiftPM handles this automatically - manual overrides are not needed

**Evidence:**
- PR #53 by Codex agent identified this exact issue: "Restore CoreXLSX build by removing stale XMLCoder include override"
- Build fails during Swift compilation phase (not dependency resolution)
- All recent builds (#51-58) fail with the same root cause

## Fix Required

Remove the `SWIFT_INCLUDE_PATHS` override from both Debug and Release configurations in `project.pbxproj`:

1. Delete line 441 (Debug configuration)
2. Delete line 498 (Release configuration)

This allows SwiftPM to handle module paths correctly for all Swift Package dependencies.

## Next Steps

1. ✅ Get full compilation error log from GitHub Actions
2. ✅ Identify root cause (stale SWIFT_INCLUDE_PATHS override)
3. ⬜ Apply fix by removing the manual include path overrides
4. ⬜ Verify build passes in CI
5. ⬜ Merge fix to main branch

---
*Report generated: 2026-04-01*
*For detailed logs, see: https://github.com/sitchomatic/rork-sitchomaticultimate/actions*
