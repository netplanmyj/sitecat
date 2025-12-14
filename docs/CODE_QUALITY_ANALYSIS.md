# Code Quality Analysis Report

**Date:** December 14, 2025  
**Version:** v1.0  
**Status:** Active Analysis (with progress markers)

---

## 📊 Codebase Overview

| Metric | Value |
|--------|-------|
| Total Dart Files | 75 |
| Total Lines of Code (lib/) | 7,268 |
| Test Files | 18 |
| Test Lines of Code | 2,336 |
| Code-to-Test Ratio | 1:0.32 |

---

## 🎯 Key Findings

### 1. Duplicate Code Detection (650+ lines identified)

#### **Issue 1.1: Provider State Management Pattern**
- **Location**: `lib/providers/` (all 5 providers)
- **Pattern**: Nearly identical initialization, event handling, error management
- **Impact**: High - affects maintenance and consistency
- **Lines Affected**: ~60 lines per provider
- **Refactor Priority**: **HIGH**

**Example Duplication:**
```dart
// Repeated in: link_checker_provider.dart, site_provider.dart, 
// monitoring_provider.dart, subscription_provider.dart
final Map<String, LinkCheckState> _checkStates = {};
final Map<String, int> _checkedCounts = {};
final Map<String, int> _totalCounts = {};
final Map<String, DateTime> _cooldownUntil = {};
final Map<String, List<LinkCheckResult>> _checkHistory = {};
// ... etc (12+ similar patterns)
```

**Suggested Solution**: Create a `BaseProvider` mixin or abstract base class

---

#### **Issue 1.2: History Screen Duplication (350+ lines)**
- **Location**: 
  - `lib/screens/monitoring_history_screen.dart` (359 lines)
  - `lib/screens/link_check_history_screen.dart` (359 lines)
- **Pattern**: 98% code identical - only data source differs
- **Impact**: **CRITICAL** - Any bug fix or feature needs duplicate updates
- **Refactor Priority**: **HIGHEST**

**Suggested Solution**: Merge into `BaseHistoryScreen` with generic type parameter

---

#### **Issue 1.3: Service Error Handling Pattern**
- **Location**: `lib/services/` (auth, subscription, monitoring, link_checker)
- **Pattern**: 6+ repetitions of similar try-catch-log-return patterns
- **Impact**: Medium - inconsistent error messages, harder to extend
- **Refactor Priority**: **MEDIUM**

---

#### **Issue 1.4: Premium Status Check**
- **Location**: LinkCheckerProvider, MonitoringProvider, SubscriptionProvider, etc.
- **Pattern**: `if (_hasLifetimeAccess) { ... } else { ... }` repeated 4+ times
- **Impact**: Medium - changes to premium logic need multiple updates
- **Suggested Solution**: Extract to `PremiumFeatureMixin`

---

### 2. Test Coverage Gaps (CRITICAL)

| File | Status | Lines | Priority | Action |
|------|--------|-------|----------|--------|
| `link_checker_provider.dart` | ✅ Tested | 539 | - | Maintain |
| `site_provider.dart` | ❌ **NO TESTS** | 321 | **CRITICAL** | Add tests |
| `monitoring_provider.dart` | ❌ **NO TESTS** | 243 | **HIGH** | Add tests |
| `monitoring_service.dart` | ❌ **NO TESTS** | 247 | **HIGH** | Add tests |
| `site.dart` (Model) | ❌ **NO TESTS** | 163 | **HIGH** | Add tests |
| `broken_link.dart` (Model) | ❌ **NO TESTS** | 198 | **HIGH** | Add tests |
| `auth_service.dart` | ❌ **NO TESTS** | 304 | **HIGH** | Add tests |
| `subscription_service.dart` | ❌ **NO TESTS** | 250 | **MEDIUM** | Add tests |

**Test Coverage Impact:**
- Current coverage ~32% (code-to-test ratio)
- Target coverage: 60%+ for core modules
- Estimated test lines needed: ~3,500 additional lines

---

### 3. Large Files (Size > 250 lines)

| File | Lines | Issue | Recommendation |
|------|-------|-------|-----------------|
| `link_checker_provider.dart` | 539 | Too many responsibilities | Split into 3 classes |
| `link_checker_service.dart` | 452 | Mixed orchestration & execution | Extract ScanOrchestrator usage |
| `profile_screen.dart` | 426 | Multiple features in one screen | Extract 5 sub-widgets |
| `monitoring_history_screen.dart` | 359 | Generic history display logic | Merge with link_check_history |
| `link_check_history_screen.dart` | 359 | Duplicate of monitoring_history | Merge into base class |
| `sites_screen.dart` | 324 | Site management & display mixed | Extract site list widget |
| `purchase_screen.dart` | 323 | Complex IAP logic | Extract IAP handling |
| `site_provider.dart` | 321 | Multiple responsibilities | Split state/actions |

**Impact**: Larger files = harder to test, debug, and understand

---

### 4. Service Layer Issues

#### **Issue 4.1: Inconsistent Error Handling**
- Different services handle errors differently
- Some log, some throw, some return null
- Makes debugging difficult

#### **Issue 4.2: Mixed Initialization Patterns**
- LinkCheckerService: Direct instantiation
- AuthService: Singleton with Firebase setup
- MonitoringService: Provider-based lazy initialization
- No consistent pattern

#### **Issue 4.3: State Management Inconsistency**
- Some providers use maps (link_checker)
- Some use individual fields (site)
- Makes pattern learning difficult

---

## 🔧 Refactoring Priorities

### **Phase 1: TEST COVERAGE (Week 1-2, CRITICAL)**
1. ⏳ Add tests for `site_provider.dart` (~300 lines of tests)
2. ⏳ Add tests for `monitoring_provider.dart` (~250 lines)
3. ⏳ Add model tests (Site, BrokenLink, etc.) (~200 lines)
4. ⏳ **Result**: 750+ new test lines, 50%+ coverage for critical modules

### **Phase 2: DUPLICATE CODE REMOVAL (Week 2-3, HIGH)**
- [x] Centralize validation logic (`lib/utils/validation.dart`), refactor `SiteProvider` and `SiteFormFields`
- [ ] Extract common dialog helpers/widgets (in progress)

### **Phase 2: DUPLICATE CODE REMOVAL (Week 2-3, HIGH)**
1. **Merge History Screens** (~350 lines saved)
   - Create `BaseHistoryScreen<T>` 
   - Reduce duplication from 359+359 → 200+50+50

2. **Create Provider Mixin** (~60 lines saved)
   - Extract common state map initialization
   - Apply to all 5 providers

3. **Extract Service Error Handling** (~40 lines saved)
   - Create `ServiceExceptionMixin`
   - Standardize error handling

### **Phase 3: LARGE FILE REFACTORING (Week 3-4, HIGH)**
1. **Split LinkCheckerProvider** (539 → 200+200+139)
   - Extract cache management
   - Extract progress tracking
   
2. **Extract ProfileScreen Widgets** (426 → 250)
   - Section widgets
   - List items

3. **Refactor LinkCheckerService** (452 → 350)
   - Reduce orchestration complexity

### **Phase 4: CONSISTENCY & CLEANUP (Week 4-5, MEDIUM)**
1. Standardize initialization patterns
2. Consistent error handling across services
3. Update documentation

---

## 📋 Recommended Issue Template

Each issue should follow this template:

```markdown
## Issue: [Type] [Module] - [Short Description]

### Category
- [ ] Duplicate Code
- [ ] Test Coverage
- [ ] Refactoring
- [ ] Documentation

### Priority
- [ ] CRITICAL (Blocks multiple issues)
- [ ] HIGH (Improves maintenance)
- [ ] MEDIUM (Nice to have)

### Files Affected
- [ ] File 1
- [ ] File 2

### Current State
- Line count: X
- Issues: Description

### Desired State
- Line count: Y (X% reduction)
- Structure: Description

### Testing Plan
- [ ] New tests added
- [ ] Existing tests updated
- [ ] Coverage: X% → Y%

### Effort Estimate
- [ ] 1-4 hours
- [ ] 4-8 hours
- [ ] 1-2 days

### Success Criteria
- [ ] Duplication reduced
- [ ] Tests passing
- [ ] Code review approved
- [ ] Documentation updated
```

---

## 🚀 Next Steps

1. **Create Phase 1 Issues** (Test Coverage) - Start with critical files
2. **Setup Test Infrastructure** - Ensure testing patterns are consistent
3. **Create Phase 2 Issues** (Duplication) - Merge history screens first
4. **Monitor Metrics** - Track lines of code, test coverage, complexity

---

## 📊 Success Metrics to Track

After refactoring complete:

| Metric | Current | Target | Impact |
|--------|---------|--------|--------|
| Code-to-Test Ratio | 1:0.32 | 1:0.6 | Better quality assurance |
| Duplicate Lines | 650+ | <100 | Easier maintenance |
| Avg File Size | 97 lines | <250 | Better readability |
| Test Coverage | 32% | 60%+ | Confidence in changes |
| Provider Consistency | 0% | 100% | Predictable patterns |

---

## 📖 For Future Reference

This document should be reviewed:
- ✅ After each major feature (check new duplication)
- ✅ Quarterly (update metrics, identify new patterns)
- ✅ Before major refactoring (use as baseline)

Keep this document in `/docs/CODE_QUALITY_ANALYSIS.md` for team reference.
