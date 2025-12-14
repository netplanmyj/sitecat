# Phase 3: Large File Refactoring Planning

**Date**: December 14, 2025  
**Status**: Planning / Ready to Start  
**Phase**: Phase 3 (after Phase 2 completion)  
**Duration**: Estimated 3-4 weeks  
**Goal**: Reduce large files, improve code readability and maintainability

---

## 📋 Overview

Phase 3 focuses on refactoring large files (500+ lines) to improve:
- **Readability**: Easier code navigation
- **Testability**: More focused, testable units
- **Maintainability**: Single responsibility principle
- **Performance**: Reduced cognitive load

---

## 🎯 Priority Tasks

### Task 3.1: Split LinkCheckerProvider (HIGHEST)

**File**: `lib/providers/link_checker_provider.dart` (539 lines)  
**Current Issues**:
- Too many responsibilities (state, caching, progress tracking)
- Multiple Map collections for tracking state
- Complex state transitions

**Refactoring Plan**:
```
BEFORE (539 lines):
link_checker_provider.dart
├─ State management (Link checker state)
├─ Progress tracking (calculated counts, percentages)
├─ Result caching (memory & display caching)
└─ Cooldown enforcement

AFTER (~200 lines each):
link_checker_provider.dart      (200 lines) - Main state & public API
link_checker_cache.dart         (200 lines) - Cache management
link_checker_progress.dart      (139 lines) - Progress calculations
```

**Split Method**:
1. Extract progress calculation logic → new `LinkCheckerProgressTracker` class
2. Extract caching logic → new `LinkCheckerCache` class
3. Provider delegates to both classes, keeps only state mgmt & listener notifications

**Tests Required**:
- [ ] Progress tracker calculates correctly (edge cases)
- [ ] Cache stores and retrieves results
- [ ] Provider integration tests

**Estimated Effort**: 8-10 hours  
**Priority**: 🔴 HIGHEST

---

### Task 3.2: Extract ProfileScreen Widgets (HIGH)

**File**: `lib/screens/profile_screen.dart` (427 lines)  
**Current Status**: Partially refactored - uses private widget classes that need to be made public
**Current Issues**:
- Private widgets (`_ProfileCard`, `_PremiumUpgradeButton`, `_SignOutButton`, `_AccountSettingsSection`) are defined in the same file
- Cannot be reused by other screens or tested independently
- Makes the file harder to navigate despite good separation

**Extraction Plan**:

| Widget | Current Location | Target Location | Responsibility |
|--------|-----------------|-----------------|-----------------|
| `_ProfileCard` | profile_screen.dart | `user_profile_card.dart` | Display user info, profile actions |
| `_PremiumUpgradeButton` | profile_screen.dart | `premium_section.dart` | Subscription status, upgrade CTA |
| `_SignOutButton` | profile_screen.dart | `sign_out_button.dart` | Sign out action |
| `_AccountSettingsSection` | profile_screen.dart | `account_settings_section.dart` | Settings toggles, preferences |
| Main `ProfileScreen` | profile_screen.dart | profile_screen.dart | Coordinator, layout |

**Result**: Private widgets become public, reusable components; ProfileScreen remains the coordinator

**Extraction Steps**:
1. Create `widgets/profile/` folder with 4 new files
2. Move private classes to their own public widget files (rename from `_ClassName` to `ClassName`)
3. Update ProfileScreen imports
4. Add widget tests for each component
5. Verify all tests pass

**Tests Required**:
- [ ] Each widget renders correctly in isolation
- [ ] Buttons trigger expected actions
- [ ] State changes propagate correctly

**Estimated Effort**: 4-6 hours  
**Priority**: 🟡 HIGH

---

### Task 3.3: Refactor LinkCheckerService (MEDIUM)

**File**: `lib/services/link_checker_service.dart` (461 lines)  
**Current Status**: Already modularized into 8 files in `link_checker/` folder  
**Current Issues**:
- Could benefit from clearer responsibility boundaries
- Some logic might be extractable to utilities

**Refactoring Plan**:
- Review current modular structure (already optimized)
- Consider if any extraction would improve clarity
- Focus on this only if time permits after Tasks 3.1 & 3.2

**Estimated Effort**: 2-4 hours (optional)  
**Priority**: 🟢 MEDIUM (deferred)

---

## 📊 Current Large Files Status

### Files > 400 lines (Priority Targets)

| File | Lines | Status | Task |
|------|-------|--------|------|
| `link_checker_provider.dart` | 539 | 🔴 TODO | 3.1 |
| `profile_screen.dart` | 426 | 🔴 TODO | 3.2 |
| `site_form_screen.dart` | 246 | ✅ DONE | Phase 1 |
| `link_checker_service.dart` | 452 | 🟡 REVIEW | 3.3 |

### Files 250-400 lines (Monitor)

| File | Lines | Status |
|------|-------|--------|
| `full_scan_section.dart` | 405 | Monitor |
| `site_detail_screen.dart` | 330 | Monitor |
| `dashboard_screen.dart` | 310 | Monitor |

---

## 🔍 Detailed Analysis

### LinkCheckerProvider Analysis

**Current Structure**:
```dart
class LinkCheckerProvider extends ChangeNotifier {
  // State maps (9 maps, ~60 lines of declarations)
  Map<String, LinkCheckState> _checkStates = {};
  Map<String, int> _checkedCounts = {};
  Map<String, int> _totalCounts = {};
  // ... 6 more maps

  // Progress calculation (~80 lines)
  int getCheckedCount(String siteId) { ... }
  int getTotalCount(String siteId) { ... }
  double getProgress(String siteId) { ... }
  // ...

  // Caching logic (~100 lines)
  void _cacheResult(String siteId, LinkCheckResult result) { ... }
  LinkCheckResult? _getCachedResult(String siteId) { ... }
  void _clearCache(String siteId) { ... }
  // ...

  // Main methods (scan, pause, resume) (~100 lines)
  Future<void> startScan(String siteId) async { ... }
  void pauseScan(String siteId) { ... }
  void resumeScan(String siteId) { ... }
  // ...

  // Event handlers & listeners (~160 lines)
  void _handleScanProgress(...) { ... }
  // ...
}
```

**Proposed Structure**:
```dart
// progress_tracker.dart
class LinkCheckerProgressTracker {
  final Map<String, int> _checkedCounts = {};
  final Map<String, int> _totalCounts = {};
  
  int getCheckedCount(String siteId) { ... }
  int getTotalCount(String siteId) { ... }
  double getProgress(String siteId) { ... }
}

// cache.dart
class LinkCheckerCache {
  final Map<String, LinkCheckResult> _cache = {};
  
  void cache(String siteId, LinkCheckResult result) { ... }
  LinkCheckResult? get(String siteId) { ... }
  void clear(String siteId) { ... }
}

// link_checker_provider.dart
class LinkCheckerProvider extends ChangeNotifier {
  final LinkCheckerProgressTracker _progressTracker;
  final LinkCheckerCache _cache;
  
  // Main state management (~200 lines)
  Future<void> startScan(String siteId) async { ... }
  void pauseScan(String siteId) { ... }
  // ... delegates to tracker and cache as needed
}
```

---

### ProfileScreen Analysis

**Current Structure**:
The current implementation (lib/screens/profile_screen.dart, 427 lines) is already a **StatelessWidget** that uses extracted private widget classes:

```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileCard(user: user),
            _PremiumUpgradeButton(),
            _SignOutButton(authProvider: authProvider),
            _AccountSettingsSection(authProvider: authProvider),
          ],
        ),
      ),
    );
  }
}

// Private widgets already exist:
class _ProfileCard extends StatelessWidget { ... }
class _PremiumUpgradeButton extends StatelessWidget { ... }
class _SignOutButton extends StatelessWidget { ... }
class _AccountSettingsSection extends StatelessWidget { ... }
```

**Current Status**: 
✅ **REFACTORING COMPLETE** - ProfileScreen is properly structured as a StatelessWidget with private widget components co-located in the same file for clarity and maintainability. No extraction to separate files needed - co-location pattern is appropriate for these tightly-coupled UI components.

**Why This Structure is Optimal**:
- Private widgets (`_ClassName`) are implementation details, not reusable APIs
- Co-location keeps related code together and reduces file navigation
- Each private widget is small and focused (< 100 lines)
- Import management is simpler (single file)
- 427 total lines is within acceptable range for a single screen



---

## 🧪 Testing Strategy

### For LinkCheckerProvider Split
- Progress tracker unit tests (no dependencies)
- Cache unit tests (simple get/set/clear)
- Provider integration tests (with mocked tracker & cache)

### For ProfileScreen Extract
- Each widget tested independently
- Mock providers where needed
- Test user interactions (taps, toggles)

---

## 📈 Expected Impact

### Metrics
| Metric | Before | After | Gain |
|--------|--------|-------|------|
| Largest file | 539 lines | 200 lines | 63% reduction |
| Avg file size | 97 lines | 85 lines | 12% reduction |
| Files > 400 lines | 2 | 0 | 100% |
| Test coverage | 362 tests | 400+ tests | +38 tests |

### Quality Benefits
- ✅ Faster code navigation (file size)
- ✅ Reduced cognitive load
- ✅ Easier to test individual components
- ✅ Better separation of concerns
- ✅ Reusable widget components

---

## 🚀 Implementation Roadmap

### Week 1 (Task 3.1)
- [ ] Day 1-2: Extract `LinkCheckerProgressTracker` class
- [ ] Day 2-3: Extract `LinkCheckerCache` class
- [ ] Day 3-4: Refactor `LinkCheckerProvider` to use both
- [ ] Day 4-5: Add tests, verify all tests pass
- [ ] End of week: PR review & merge

### Week 2 (Task 3.2)
- [ ] Day 1-2: Extract `UserProfileCard` widget
- [ ] Day 2-3: Extract subscription & preferences sections
- [ ] Day 3-4: Extract `AppInfoSection`, simplify main screen
- [ ] Day 4-5: Add widget tests
- [ ] End of week: PR review & merge

### Week 3 (Task 3.3 - Optional)
- [ ] Review `LinkCheckerService` modular structure
- [ ] Determine if additional refactoring needed
- [ ] If needed: extract and test
- [ ] If not needed: document decision

---

## ✅ Definition of Done

For each task:
1. ✅ Code split/refactored per plan
2. ✅ All new classes/widgets have unit/widget tests
3. ✅ `flutter analyze` passes (no warnings)
4. ✅ `dart format` passes
5. ✅ `flutter test` passes (all tests including new ones)
6. ✅ PR created with clear description
7. ✅ PR reviewed and approved
8. ✅ PR merged to main
9. ✅ This document updated with completion status

---

## 📝 Progress Tracking

**Status**: All tasks analyzed; awaiting implementation planning for next phase.

| Task | Status | Effort | Priority |
|------|--------|--------|----------|
| 3.1 - LinkCheckerProvider Split | Not Started | 8h | HIGH |
| 3.2 - ProfileScreen Extract | Not Started | 4-6h | MEDIUM |
| 3.3 - LinkCheckerService Refactor | Optional | 2-4h | MEDIUM |

---

## 📚 Related Documentation

- [CODE_REFACTORING_ROADMAP.md](./CODE_REFACTORING_ROADMAP.md) - Overall strategy
- [CODE_QUALITY_ANALYSIS.md](./CODE_QUALITY_ANALYSIS.md) - Metrics & findings
- [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) - Architecture patterns
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) - Coding standards

---

**Last Updated**: December 14, 2025  
**Next Review**: December 28, 2025
