# Code Refactoring Roadmap

**Document Version**: v1.0  
**Last Updated**: December 14, 2025  
**Status**: Active Planning (with progress updates)

---

## 📋 Overview

This roadmap outlines the systematic refactoring of the sitecat codebase to improve:
- **Maintainability**: Reduce duplicate code
- **Testability**: Increase test coverage to 60%+
- **Consistency**: Standardize patterns across modules
- **Performance**: Optimize large files and complex methods

---

## 🎯 Phase 1: Test Coverage (CRITICAL)

**Duration**: Week 1-2  
**Goal**: Increase test coverage from 32% to 50%+  
**Impact**: High - enables safe refactoring

### Task 1.1: SiteProvider Tests
**File**: `lib/providers/site_provider.dart` (321 lines)  
**Current**: ❌ No tests  
**Effort**: 4-8 hours  
**Priority**: CRITICAL  

**Tests to Add**:
- [ ] `loadSites()` - Firebase loading
- [ ] `addSite()` - Creation with validation
- [ ] `updateSite()` - Updates and state sync
- [ ] `deleteSite()` - Deletion and cleanup
- [ ] `excludedPaths` - Excluded paths logic
- [ ] Error handling - Network failures, permissions

**Success Criteria**: 
- [ ] 20+ test cases
- [ ] 80%+ line coverage for site_provider.dart
- [ ] All tests green

**GitHub Issue**: #264 - Add SiteProvider unit tests

---

### Task 1.2: MonitoringProvider Tests
**File**: `lib/providers/monitoring_provider.dart` (243 lines)  
**Current**: ❌ No tests  
**Effort**: 3-6 hours  
**Priority**: CRITICAL  

**Tests to Add**:
- [ ] Site monitoring lifecycle
- [ ] Result caching
- [ ] Error aggregation
- [ ] Listener management
- [ ] State transitions

**GitHub Issue**: #265 - Add MonitoringProvider unit tests

---

### Task 1.3: Model Tests (Site, BrokenLink)
**Files**: 
- `lib/models/site.dart` (163 lines)
- `lib/models/broken_link.dart` (198 lines)  
**Current**: ❌ No tests  
**Effort**: 3-4 hours  
**Priority**: CRITICAL  

**Tests to Add**:
- [ ] JSON serialization/deserialization
- [ ] Firestore conversion
- [ ] Data validation
- [ ] Edge cases

**GitHub Issue**: #266 - Add model unit tests

---

### Task 1.4: Service Layer Tests
**Files**: 
- `lib/services/monitoring_service.dart` (247 lines)
- `lib/services/auth_service.dart` (304 lines)  
**Current**: ❌ No tests  
**Effort**: 4-8 hours  
**Priority**: HIGH  

**Tests to Add**:
- [ ] Service initialization
- [ ] Authentication flow
- [ ] Monitoring operations
- [ ] Error handling

**GitHub Issue**: #267 - Add service layer unit tests

---

## 🔧 Phase 2: Duplicate Code Removal (HIGH)

**Duration**: Week 2-3  
**Goal**: Reduce duplicate code from 650+ lines to <100 lines  
**Impact**: Medium - improves maintenance

### Task 2.1: Merge History Screens
**Files**:
- `lib/screens/monitoring_history_screen.dart` (359 lines)
- `lib/screens/link_check_history_screen.dart` (359 lines)  
**Current**: 98% duplication  
**Effort**: 6-8 hours  
**Priority**: HIGHEST  

**Solution**: Create `BaseHistoryScreen<T>` generic widget

**Before**:
```
monitoring_history_screen.dart    (359 lines)
link_check_history_screen.dart    (359 lines)
────────────────────────────────────────────
Total: 718 lines (718 of duplication)
```

**After**:
```
base_history_screen.dart          (200 lines)
monitoring_history_screen.dart    (50 lines)  
link_check_history_screen.dart    (50 lines)
────────────────────────────────────────────
Total: 300 lines (418 line reduction!)
```

**Refactoring Steps**:
1. [ ] Extract common UI patterns to `BaseHistoryScreen<T>`
2. [ ] Update both screens to extend base
3. [ ] Add tests for base class
4. [ ] Update existing tests
5. [ ] Verify on device

**GitHub Issue**: #268 - Merge duplicate history screens

---

### Task 2.2: Create Provider Base Mixin
**Files**: All `lib/providers/*.dart`  
**Current**: 60+ lines duplicated across 5 providers  
**Effort**: 4-6 hours  
**Priority**: HIGH  

**Solution**: Extract common state map patterns

**Example Pattern**:
```dart
// Current (repeated 5 times):
final Map<String, LinkCheckState> _checkStates = {};
final Map<String, int> _checkedCounts = {};
final Map<String, int> _totalCounts = {};
// ... 9 more similar maps

// After mixin:
mixin CacheableProvider on ChangeNotifier {
  final Map<String, T> _stateCache = {};
  // Common methods
}
```

**GitHub Issue**: #269 - Extract provider base mixin

---

### Task 2.3: Standardize Error Handling
**Files**: `lib/services/` (all services)  
**Current**: 6+ different error patterns  
**Effort**: 3-4 hours  
**Priority**: MEDIUM  

**Solution**: Create `ServiceErrorMixin`

**GitHub Issue**: #270 - Standardize service error handling

---

## ✅ Progress Update (2025-12-14)

**Phase 2 COMPLETED** ✅
- [x] Copilot contribution guidelines added and merged (PR #278)
- [x] Validation utils centralized (`lib/utils/validation.dart`) - 4 validators (siteName, siteUrl, sitemapInput, checkInterval)
  - Applied in: `SiteProvider` (3 validators), `SiteFormFields` (1 validator)
  - Test coverage: `test/utils/validation_test.dart` (64 lines, all edge cases)
  - PR #280 merged
- [x] Dialog helpers/widgets extraction (`lib/utils/dialogs.dart`) - 3 reusable patterns (confirm, info, error)
  - Applied in: `SitesScreen`, `MySitesSection`, `DemoModeBadge`
  - Test coverage: `test/utils/dialogs_test.dart` (116 lines, behavior tests)
  - PR #280 merged
- [x] BuildContext safety patterns implemented (ScaffoldMessenger pre-capture)
- [x] 362 tests passing (+20 new tests for validation & dialogs)
- [x] All CI checks passing (analyze, format, test)

**Phase 2 Summary**:
- Centralized form validation logic → reduces duplication, ensures consistency
- Reusable dialog patterns → standardizes UI interactions across app
- Added 20+ tests → improves confidence in utility functions
- Code deletion: Removed 153 lines of duplication, improved maintainability

**Next**: Phase 3 Large File Refactoring

## 📦 Phase 3: Large File Refactoring (HIGH)

**Duration**: Week 3-4  
**Goal**: Reduce average file size; improve readability  
**Impact**: Medium-High - improves code navigation

### Task 3.1: Split LinkCheckerProvider
**File**: `lib/providers/link_checker_provider.dart` (539 lines)  
**Current**: Too many responsibilities  
**Effort**: 8 hours  
**Priority**: HIGH  

**Refactor Plan**:
```
link_checker_provider.dart (539 lines)
├─ link_checker_provider.dart (200 lines) - Core state
├─ link_checker_cache.dart (200 lines) - Cache management  
├─ link_checker_progress.dart (139 lines) - Progress tracking
```

**Responsibilities**:
- Core provider: State initialization, main methods
- Cache class: precalculated counts, result caching
- Progress class: Progress calculation, notifications

**GitHub Issue**: #271 - Split LinkCheckerProvider

---

### Task 3.2: Extract ProfileScreen Widgets
**File**: `lib/screens/profile_screen.dart` (426 lines)  
**Current**: Multiple features in one screen  
**Effort**: 4-6 hours  
**Priority**: MEDIUM  

**Extract to separate widgets**:
- [ ] `UserProfileCard` (80 lines)
- [ ] `SubscriptionSection` (100 lines)
- [ ] `PreferencesSection` (90 lines)
- [ ] `AppInfoSection` (50 lines)

**Result**: Main screen becomes 106 lines (75% reduction)

**GitHub Issue**: #272 - Extract ProfileScreen sub-widgets

---

### Task 3.3: Refactor LinkCheckerService
**File**: `lib/services/link_checker_service.dart` (452 lines)  
**Current**: Mixed orchestration & execution  
**Effort**: 6-8 hours  
**Priority**: MEDIUM  

**Changes**:
- Better separation with ScanOrchestrator
- Extract result building
- Simplify main checkSiteLinks method

**GitHub Issue**: #273 - Refactor LinkCheckerService composition

---

## 🎓 Phase 4: Consistency & Documentation (MEDIUM)

**Duration**: Week 4-5  
**Goal**: Standardize patterns; improve discoverability  
**Impact**: Low-Medium - improves team velocity

### Task 4.1: Service Initialization Standards
**Effort**: 3-4 hours  
**Priority**: MEDIUM  

**Create**: `docs/SERVICE_INITIALIZATION_GUIDE.md`
- Standardized patterns
- Examples for each service type
- Error handling standards

**GitHub Issue**: #274 - Document service initialization standards

---

### Task 4.2: Provider Pattern Documentation
**Effort**: 2-3 hours  
**Priority**: MEDIUM  

**Create**: `docs/PROVIDER_DEVELOPMENT_GUIDE.md`
- Base mixin usage
- Common state management patterns
- Testing requirements

**GitHub Issue**: #275 - Document provider development guide

---

## 📊 Expected Outcomes

### Code Metrics
| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Total Lines | 7,268 | 6,850 | -418 (-6%) |
| Duplicate Lines | 650+ | <100 | -550+ (-85%) |
| Avg File Size | 97 | 85 | -12% |
| Test Lines | 2,336 | 5,800+ | +3,500+ |
| Test Coverage | 32% | 60%+ | +28% |

### Quality Improvements
- ✅ 85% reduction in duplicate code
- ✅ 2x test coverage
- ✅ Standardized patterns across codebase
- ✅ Easier debugging (clear file boundaries)
- ✅ Faster new feature development

### Risk Mitigation
- ✅ Phase 1 (tests) enables safe refactoring
- ✅ Small incremental changes in each task
- ✅ All work verified with existing + new tests

---

## 🚀 Implementation Schedule

```
Week 1-2:  Phase 1 (Test Coverage) - CRITICAL
           └─ 4 issues: #264, #265, #266, #267

Week 2-3:  Phase 2 (Duplication) - HIGH  
           └─ 3 issues: #268, #269, #270

Week 3-4:  Phase 3 (Large Files) - HIGH
           └─ 3 issues: #271, #272, #273

Week 4-5:  Phase 4 (Documentation) - MEDIUM
           └─ 2 issues: #274, #275
```

---

## 📌 Tracking Progress

Each task should:
1. ✅ Have a GitHub issue with this roadmap reference
2. ✅ Include PR with descriptive commits
3. ✅ Add tests (Phase 1+)
4. ✅ Update this document when complete
5. ✅ Request review before merge

---

## 🔄 Maintenance & Updates

**Review Frequency**: Monthly  
**Update Triggers**:
- After Phase 1 complete (adjust timeline)
- New duplication patterns found
- New architectural decisions

---

## 📚 Related Documents

- [CODE_QUALITY_ANALYSIS.md](./CODE_QUALITY_ANALYSIS.md) - Current state analysis
- [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) - Development practices
- [Architecture decisions](./ARCHITECTURE.md) - System design

---

## 👥 Approval

- [ ] Author Review (Copilot)
- [ ] Owner Approval (User)
- [ ] Scheduled Execution

