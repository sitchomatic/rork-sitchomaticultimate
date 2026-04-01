# Plan: Fix iOS Build Errors

## Problem Statement
The iOS Build workflow is failing on the main branch (run #23827800555). Recent attempts (PRs #38, #39, #40) tried to fix the build by:
- Disabling warnings-as-errors flags
- Adding XMLCoder dependency for CoreXLSX
- Fixing project settings (CLANG_WARN_DIRECT_OBJC_ISA_USAGE, etc.)

However, all builds continue to fail.

## Investigation Status
From the CI logs:
- Packages resolve successfully (CoreXLSX, XMLCoder, ZIPFoundation)
- SitchomaticWidget Swift files compile successfully (CommandCenterActivityAttributes.swift, CommandCenterLiveActivity.swift, etc.)
- Dependencies (ZIPFoundation, XMLCoder) compile and link successfully
- The build process continues past the widget compilation...
- **Unable to see the actual error** due to log truncation (>25,000 tokens)

## Next Steps
1. **Get full error details**: Need to identify the specific compilation error
   - Try getting logs from different job steps
   - Search for "error:" or "**BUILD FAILED**" in logs

2. **Likely issues based on context**:
   - Main app target (Sitchomatic) may have compilation errors
   - Test targets (SitchomaticTests, SitchomaticUITests) may fail
   - Swift 6 concurrency issues in non-widget code

3. **Fix strategy**: Once error is identified, fix the root cause

## Files Reviewed
- `.github/workflows/ios-build.yml` - CI workflow (warnings allowed)
- `ios/SitchomaticWidget/*.swift` - Widget code (looks clean, compiles successfully)
- Recent commit history - Multiple fix attempts

## Status
✅ **ROOT CAUSE IDENTIFIED**: Swift 6 actor isolation violation

## Build Error Analysis

### Primary Issue: Actor Isolation Violation in NetworkSessionFactory.swift:503

**Error Location**: `ios/Sitchomatic/Services/NetworkSessionFactory.swift`

The function `quickSOCKS5Handshake` is marked as `nonisolated` but is defined within a `@MainActor` class. In Swift 6, this creates an actor isolation violation because:
1. Line 41: The class is marked `@MainActor class NetworkSessionFactory`
2. Line 503: Method `nonisolated private func quickSOCKS5Handshake` attempts to escape MainActor isolation
3. The function is called from line 352 in `preflightProxyCheck` (which runs on MainActor)
4. Swift 6 strict concurrency checking rejects this pattern

**Fix**: Remove the `@MainActor` annotation from `NetworkSessionFactory` since:
- The class doesn't actually need MainActor isolation
- It's primarily used for network operations (URLSession, WKWebView configuration)
- Its singleton `.shared` is accessed from various actors/isolation domains
- Making it a regular class (with internal Sendable-safe state) resolves the issue

### Secondary Issue: HyperFlowExecutor Sendable Conformance

**Location**: `ios/Sitchomatic/Services/HyperFlowEngine.swift:33`

The class uses `@unchecked Sendable` which bypasses Swift 6's safety checks. This is acceptable for this specific case since `DispatchQueue` is thread-safe, but should be documented.
