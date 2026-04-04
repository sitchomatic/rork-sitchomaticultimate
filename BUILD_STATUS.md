# iOS Build Status Report

## Current Status
**Status:** ❌ FAILING (latest CI run #79)
**Last Successful Build:** Unknown (all recent builds failing)
**Build Workflow:** `.github/workflows/ios-build.yml`
**Latest Failed Run:** #79 (commit 27dbe19)

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

**Issue:** `CoreXLSX` cannot locate the `XMLCoder` module during compilation.

**Evidence:** Latest CI logs (#79) show `no such module 'XMLCoder'` while compiling `XLSXFile.swift` inside the `CoreXLSX` package.

**Root cause:** The build settings did not propagate the SourcePackages module search path for SwiftPM dependencies, so CoreXLSX was compiled without being able to see XMLCoder’s built module artifacts.

**Fix Applied:** Added an explicit `SWIFT_INCLUDE_PATHS` entry to the project-level Debug/Release configurations in `ios/Sitchomatic.xcodeproj/project.pbxproj` pointing to the SwiftPM checkout build outputs for `XMLCoder` and `ZIPFoundation`:

```
SWIFT_INCLUDE_PATHS = "$(inherited) $(BUILD_DIR)/../../SourcePackages/checkouts/XMLCoder/build/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME) $(BUILD_DIR)/../../SourcePackages/checkouts/ZIPFoundation/build/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)";
```

This ensures Swift sees the dependency modules when compiling CoreXLSX.

## Next Steps

1. ✅ Get full compilation error log from GitHub Actions
2. ✅ Identify root cause (missing XMLCoder module search path in CoreXLSX build)
3. ✅ Add include search paths so CoreXLSX can import XMLCoder
4. ⬜ Verify build passes in CI
5. ⬜ Merge fix to main branch

---
*Report generated: 2026-04-01*
*For detailed logs, see: https://github.com/sitchomatic/rork-sitchomaticultimate/actions*
