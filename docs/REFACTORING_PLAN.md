# Refactoring Plan

**Based on:** [CODEBASE_ANALYSIS_REPORT.md](./CODEBASE_ANALYSIS_REPORT.md)  
**Version:** 1.0  
**Status:** Planning  
**Target Completion:** v1.0.9 (before Android Phase 1)

---

## Overview

This document provides an actionable refactoring plan based on the comprehensive codebase analysis. The plan is divided into 4 phases with clear priorities, effort estimates, and success criteria.

---

## Phase 1: Test Coverage Expansion 🚨 CRITICAL

**Goal:** Increase test coverage from 32% to 50%+  
**Priority:** P0 (Must complete before other refactoring)  
**Duration:** 2-3 weeks  
**Effort:** 12-18 hours  

### Why Phase 1 is Critical
- **Safety net for refactoring:** Cannot safely refactor without tests
- **Bug prevention:** Critical providers handle data persistence and IAP
- **Confidence:** Enables aggressive optimization in later phases

### Tasks

#### Task 1.1: SiteProvider Tests (#264)
**Priority:** P0 🚨  
**Effort:** 4-6 hours  
**Files:** `test/providers/site_provider_test.dart`

**Test Coverage:**
- ✅ loadSites() - Firebase fetch
- ✅ addSite() - Validation, creation
- ✅ updateSite() - Excluded paths detection, index reset
- ✅ deleteSite() - Cascade delete checks
- ✅ Site limit enforcement (free: 5, premium: 30)

**Acceptance Criteria:**
- 20+ tests passing
- All public methods covered
- Edge cases tested (empty data, network errors)

---

#### Task 1.2: MonitoringProvider Tests (#265)
**Priority:** P0 🚨  
**Effort:** 5-7 hours  
**Files:** `test/providers/monitoring_provider_test.dart`

**Test Coverage:**
- ✅ checkSite() - Quick scan logic
- ✅ listenToSiteResults() - Firestore real-time updates
- ✅ Cooldown enforcement
- ✅ Result caching
- ✅ getCachedSitemapStatus()

**Acceptance Criteria:**
- 25+ tests passing
- Async operations properly tested
- Cooldown logic verified

---

#### Task 1.3: Model Tests (#267)
**Priority:** P1 ⚠️  
**Effort:** 3-5 hours  
**Files:** `test/models/*_test.dart`

**Test Coverage:**
- ✅ Site.fromFirestore() / toFirestore()
- ✅ BrokenLink validation
- ✅ LinkCheckResult serialization
- ✅ Edge cases (null fields, invalid data)

**Acceptance Criteria:**
- 15+ tests passing
- Serialization round-trip verified
- Validation logic covered

---

### Phase 1 Deliverables
- [ ] 3 new test files created
- [ ] 68+ new tests added
- [ ] Test coverage: 32% → 50%+
- [ ] All tests green (CI passing)
- [ ] Code review completed

### Phase 1 Timeline
```
Week 1: Task 1.1 (SiteProvider) + Task 1.2 (MonitoringProvider)
Week 2: Task 1.3 (Models)
Week 3: Buffer for issues, code review, documentation
```

---

## Phase 2: Code Duplication Removal ⚠️ HIGH

**Goal:** Reduce code duplication by 20%  
**Priority:** P1  
**Duration:** 1-2 weeks  
**Effort:** 8-12 hours  

### Tasks

#### Task 2.1: Cooldown Unification (#256)
**Priority:** P1 ⚠️  
**Effort:** 4-6 hours  
**Status:** ✅ Already planned in v1.0.8

**Current State:**
```dart
// LinkCheckerProvider
final Map<String, DateTime> _cooldownUntil = {};
Duration? getTimeUntilNextCheck(String siteId) { ... }

// MonitoringProvider  
final Map<String, DateTime> _nextCheckTime = {};
Duration? getTimeUntilNextCheck(String siteId) { ... }
```

**Proposed Solution:**
```dart
// New: lib/services/cooldown_service.dart
class CooldownService {
  final Map<String, DateTime> _cooldownUntil = {};
  
  void startCooldown(String id, Duration duration) { ... }
  Duration? getTimeUntilNextCheck(String id) { ... }
  bool canPerformAction(String id) { ... }
}

// Usage in providers
final _cooldownService = CooldownService();
```

**Benefits:**
- Single source of truth
- Consistent cooldown behavior
- Easier to test
- ~30 lines saved

**Acceptance Criteria:**
- New `CooldownService` created
- Both providers use it
- All existing tests pass
- New cooldown service tests added

---

#### Task 2.2: Validation Utils Extraction (#268)
**Priority:** P1  
**Effort:** 2-3 hours

**Duplication:**
```dart
// SiteFormScreen, SiteService, etc.
if (!url.startsWith('http://') && !url.startsWith('https://')) {
  return 'URL must start with http:// or https://';
}
```

**Solution:**
```dart
// lib/utils/validation_utils.dart
class ValidationUtils {
  static String? validateSiteUrl(String url) {
    if (url.isEmpty) return 'URL cannot be empty';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    // Additional validation...
    return null; // Valid
  }
  
  static String? validateSitemapUrl(String? url) { ... }
}
```

**Benefits:**
- Consistent validation
- Single place to update rules
- Testable in isolation
- ~15 lines saved

---

#### Task 2.3: Dialog Pattern Extraction
**Priority:** P2 (Optional)  
**Effort:** 2-3 hours

**Pattern:**
```dart
// Repeated: Delete confirmation dialogs
showDialog(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Delete Site'),
    content: Text('Are you sure...'),
    actions: [Cancel, Delete buttons],
  ),
);
```

**Solution:**
```dart
// lib/widgets/common/confirmation_dialog.dart
class ConfirmationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Delete',
  }) { ... }
}
```

---

### Phase 2 Deliverables
- [ ] CooldownService created and integrated
- [ ] ValidationUtils extracted
- [ ] Code duplication: ~8% → ~6%
- [ ] All tests green
- [ ] Documentation updated

---

## Phase 3: Complexity Reduction 📊 MEDIUM

**Goal:** Simplify high-complexity methods  
**Priority:** P2  
**Duration:** 2-3 weeks  
**Effort:** 12-18 hours  

### Tasks

#### Task 3.1: LinkCheckerService Refactoring (#269)
**Priority:** P2  
**Effort:** 6-8 hours

**Current:** checkSiteLinks() - 200 lines, complexity ~15-20

**Refactoring Steps:**
1. Extract sitemap loading
2. Extract link extraction per page
3. Extract link validation
4. Extract result building

**Proposed Structure:**
```dart
class LinkCheckerService {
  // Main orchestration (simplified)
  Future<LinkCheckResult> checkSiteLinks(...) async {
    final sitemap = await _loadAndValidateSitemap(site);
    final pageRange = _calculateScanRange(sitemap, site);
    final links = await _extractLinksFromPages(pageRange, ...);
    final validated = await _validateLinks(links, ...);
    return await _buildResult(validated, site, ...);
  }
  
  // Private extracted methods
  Future<SitemapData> _loadAndValidateSitemap(...) { ... }
  ScanRange _calculateScanRange(...) { ... }
  Future<LinkCollection> _extractLinksFromPages(...) { ... }
  Future<ValidationResult> _validateLinks(...) { ... }
  Future<LinkCheckResult> _buildResult(...) { ... }
}
```

**Benefits:**
- Each method has single responsibility
- Easier to test individual steps
- Complexity: 15-20 → 5-7 per method
- Better readability

**Acceptance Criteria:**
- Method extracted into 5+ smaller methods
- All existing tests pass
- New unit tests for extracted methods
- No behavior change

---

#### Task 3.2: SiteScanSection Simplification
**Priority:** P2  
**Effort:** 3-4 hours

**Current:** Large build() method with complex state

**Solution:**
```dart
class SiteScanSection extends StatefulWidget {
  // Extract helper widgets
  Widget _buildProgressSection() { ... }
  Widget _buildControlButtons() { ... }
  Widget _buildExternalLinksCheckbox() { ... }
  
  // Extract logic methods
  bool _canStartScan() { ... }
  bool _canContinueScan() { ... }
  bool _isInCooldown() { ... }
}
```

---

#### Task 3.3: LinkExtractor Refactoring
**Priority:** P3 (Optional)  
**Effort:** 3-4 hours

**Goal:** Split link extraction logic

---

### Phase 3 Deliverables
- [ ] checkSiteLinks() refactored
- [ ] SiteScanSection simplified
- [ ] Complexity metrics improved
- [ ] All tests green
- [ ] Performance unchanged

---

## Phase 4: Documentation 📝 LOW

**Goal:** Complete architecture documentation  
**Priority:** P3  
**Duration:** 1 week  
**Effort:** 6-10 hours  

### Tasks

#### Task 4.1: Architecture Diagrams (#270)
**Effort:** 3-4 hours

**Deliverables:**
- System architecture diagram
- Provider interaction diagram
- Service layer diagram
- Data flow diagrams

#### Task 4.2: API Documentation
**Effort:** 2-3 hours

**Deliverables:**
- Service method documentation
- Provider API docs
- Widget usage examples

#### Task 4.3: Development Guide Updates
**Effort:** 1-2 hours

**Deliverables:**
- Update DEVELOPMENT_GUIDE.md
- Testing strategy docs
- Contribution guidelines

---

## Success Metrics

### Phase 1 Success Criteria
- ✅ Test coverage: 32% → 50%+
- ✅ 80+ new tests added
- ✅ All critical providers tested
- ✅ Zero test failures

### Phase 2 Success Criteria
- ✅ Code duplication: ~8% → ~6%
- ✅ Cooldown logic unified
- ✅ Validation extracted
- ✅ No regressions

### Phase 3 Success Criteria
- ✅ Complexity reduced by 30%
- ✅ Methods avg <50 lines
- ✅ Better maintainability score
- ✅ No performance degradation

### Phase 4 Success Criteria
- ✅ All major components documented
- ✅ Architecture diagrams complete
- ✅ Developer onboarding improved

---

## Risk Management

### Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Tests break existing functionality | Medium | High | Write tests incrementally, run full suite |
| Refactoring introduces bugs | Medium | High | Test-first approach, code review |
| Timeline slips | Medium | Low | Buffer time in each phase |
| Scope creep | Low | Medium | Stick to plan, track issues |

### Rollback Plan
- Each phase is independent
- Changes are incremental
- Git history allows easy rollback
- Feature flags for risky changes

---

## Timeline & Milestones

```
Week 1-3:  Phase 1 (Test Coverage)
  ├─ Week 1: SiteProvider + MonitoringProvider tests
  ├─ Week 2: Model tests  
  └─ Week 3: Review, fixes, documentation

Week 4-5:  Phase 2 (Duplication Removal)
  ├─ Task 2.1: Cooldown unification (#256)
  └─ Task 2.2: Validation extraction

Week 6-8:  Phase 3 (Complexity Reduction)
  ├─ Task 3.1: LinkCheckerService refactoring
  └─ Task 3.2: Widget simplification

Week 9:    Phase 4 (Documentation)
  └─ Architecture docs, diagrams

Week 10:   Buffer & Final Review
```

**Total Duration:** ~10 weeks (2.5 months)  
**Total Effort:** 38-58 hours

---

## Next Steps

### Immediate Actions
1. ✅ Review and approve this plan
2. 🔲 Create GitHub Issues #264-#270
3. 🔲 Start Phase 1: Task 1.1 (SiteProvider tests)
4. 🔲 Set up tracking dashboard

### Tracking
- Use GitHub Project board
- Weekly progress reviews
- Update metrics after each phase
- Document lessons learned

---

**Plan Maintained By:** AI Assistant  
**Last Updated:** 2025-12-11  
**Next Review:** After Phase 1 completion
