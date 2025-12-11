# Phase 1: Test Coverage Issues (CRITICAL)

**Timeline**: Week 1-2  
**Goal**: Increase test coverage from 32% to 50%+  
**Related Documents**: 
- [CODE_QUALITY_ANALYSIS.md](./CODE_QUALITY_ANALYSIS.md)
- [CODE_REFACTORING_ROADMAP.md](./CODE_REFACTORING_ROADMAP.md)

---

## Issue #264: Add SiteProvider unit tests

### Type
Test Coverage

### Priority
CRITICAL

### Description
SiteProvider (321 lines) currently has no test coverage. This is a critical provider managing site CRUD operations and must be tested before any refactoring.

### Files Affected
- lib/providers/site_provider.dart

### Test Cases to Implement
- [ ] `loadSites()` - Firebase loading and state update
- [ ] `addSite()` - Creation with validation
- [ ] `updateSite()` - Updates and state sync
- [ ] `deleteSite()` - Deletion and cleanup
- [ ] `excludedPaths` - Excluded paths change detection
- [ ] Error handling - Network failures, permissions
- [ ] State listeners - Notification behavior

### Success Criteria
- [ ] 20+ test cases written
- [ ] 80%+ line coverage for site_provider.dart
- [ ] All tests passing
- [ ] No lint warnings

### Effort Estimate
4-8 hours

---

## Issue #265: Add MonitoringProvider unit tests

### Type
Test Coverage

### Priority
CRITICAL

### Description
MonitoringProvider (243 lines) currently has no test coverage. This is a critical provider for site monitoring functionality.

### Files Affected
- lib/providers/monitoring_provider.dart

### Test Cases to Implement
- [ ] Site monitoring lifecycle
- [ ] Result caching mechanism
- [ ] Error aggregation
- [ ] Listener management
- [ ] State transitions
- [ ] Cooldown enforcement

### Success Criteria
- [ ] 15+ test cases written
- [ ] 80%+ line coverage
- [ ] All tests passing

### Effort Estimate
3-6 hours

---

## Issue #266: Add model unit tests

### Type
Test Coverage

### Priority
CRITICAL

### Description
Core model classes (Site, BrokenLink) lack test coverage. These models are fundamental to data handling.

### Files Affected
- lib/models/site.dart (163 lines)
- lib/models/broken_link.dart (198 lines)

### Test Cases to Implement

**For Site model:**
- [ ] JSON serialization/deserialization
- [ ] Firestore conversion
- [ ] Data validation
- [ ] Display format methods (displayUrl, lastCheckedDisplay)
- [ ] copyWith() functionality

**For BrokenLink model:**
- [ ] JSON serialization/deserialization
- [ ] Status code handling
- [ ] Error message formatting

### Success Criteria
- [ ] 25+ test cases written
- [ ] 85%+ line coverage for both models
- [ ] All tests passing

### Effort Estimate
3-4 hours

---

## Issue #267: Add service layer unit tests

### Type
Test Coverage

### Priority
HIGH

### Description
Core services (MonitoringService, AuthService) lack test coverage, making debugging difficult when issues arise.

### Files Affected
- lib/services/monitoring_service.dart (247 lines)
- lib/services/auth_service.dart (304 lines)

### Test Cases to Implement

**For MonitoringService:**
- [ ] Service initialization
- [ ] Site checking operations
- [ ] Error handling and recovery
- [ ] Firebase integration

**For AuthService:**
- [ ] Authentication flow
- [ ] User session management
- [ ] Error handling

### Success Criteria
- [ ] 20+ test cases written
- [ ] 75%+ line coverage
- [ ] All tests passing

### Effort Estimate
4-8 hours

---

## Summary

| Issue | Task | Priority | Effort | Tests |
|-------|------|----------|--------|-------|
| #264 | SiteProvider tests | CRITICAL | 4-8h | 20+ |
| #265 | MonitoringProvider tests | CRITICAL | 3-6h | 15+ |
| #266 | Model tests | CRITICAL | 3-4h | 25+ |
| #267 | Service layer tests | HIGH | 4-8h | 20+ |

**Total Effort**: 14-26 hours  
**Total New Tests**: 80+  
**Expected Coverage Increase**: 32% → 50%+

---

## Next Steps

1. Create issues #264-#267 on GitHub
2. Assign to development
3. Work through Phase 1 sequentially
4. Move to Phase 2 once Phase 1 is complete

See [CODE_REFACTORING_ROADMAP.md](./CODE_REFACTORING_ROADMAP.md) for complete roadmap.
