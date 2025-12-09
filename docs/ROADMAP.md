# SiteCat Development Roadmap

## Current Release
- **v1.0.6** (Current)
  - ✅ UI/UX improvements (Results card page range display, Sitemap button cooldown)
  - ✅ Critical bug fixes (Premium user 200-page scan limit)
  - ✅ Code quality improvements

---

## Phase 1: Android Platform Support (v1.1)

### Timeline
- **Duration**: 2-3 weeks
- **Start**: After v1.0.6 App Store approval

### Objectives
- ✨ Launch SiteCat on Android platform
- 🔄 Port existing iOS features to Android
- 🛠️ Refactor shared code for platform consistency

### Scope
- **Free Plan**: 200 pages/scan, 3 sites, 10 history records
- **Premium Plan**: Lifetime IAP (¥3,000)
  - 1000 pages/scan
  - 30 sites
  - 50 history records
  - Excluded paths feature

### Key Activities
1. **Platform Abstraction**
   - Separate iOS/Android-specific code
   - Extract common business logic
   - Unify IAP interface

2. **Code Refactoring**
   - Optimize Firebase initialization
   - Standardize environment configuration (Dev/Prod)
   - Clean up dependency structure

3. **Build Optimization**
   - Update build.gradle.kts for Android
   - Verify Podfile dependencies (iOS)
   - Ensure plugin compatibility

4. **Testing**
   - Add Android-specific test coverage
   - Validate IAP flow on both platforms
   - Cross-platform integration testing

### Deliverables
- Android app on Google Play
- Unified codebase with platform abstraction
- Comprehensive test coverage for both platforms

---

## Phase 2: Subscription Model (v1.2)

### Timeline
- **Duration**: 3-4 weeks
- **Start**: After v1.1 Android launch

### Objectives
- 💰 Implement recurring revenue model
- 📈 Support subscription tiers on both platforms
- 🔄 Maintain feature parity between iOS and Android

### Scope
- **Subscription Plans**:
  - Monthly subscription
  - Annual subscription
  - Continue Lifetime option

- **Supported Platforms**: iOS + Android

### Key Features
- Subscription management in Profile
- Free trial support (if applicable)
- Restore purchases functionality
- Server-side subscription validation

### Key Activities
1. **Backend Integration**
   - Implement subscription verification in Cloud Functions
   - Add subscription management endpoints
   - Set up webhook handlers for App Store/Google Play

2. **UI/UX Updates**
   - Redesign pricing screen
   - Add subscription management interface
   - Implement subscription status indicators

3. **Platform Implementation**
   - StoreKit 2 integration (iOS)
   - Google Play Billing Library 8.0+ (Android)
   - Unified purchase flow

4. **Testing & Quality**
   - Sandbox environment testing
   - Subscription renewal scenarios
   - Edge case handling (cancellations, expirations)

### Deliverables
- Subscription system on both platforms
- Unified monetization model
- Improved revenue potential

---

## Future Considerations (v1.3+)

- Progress bar visibility improvements (Issue #247)
- Advanced monitoring features
- API integration for external tools
- Enhanced analytics dashboard
- Multi-language support expansion

---

## Development Principles

- **Code Quality First**: Refactoring during platform expansion
- **Platform Parity**: Keep iOS and Android feature sets synchronized
- **User-Centric**: Maintain core functionality accessibility in free tier
- **Testing Coverage**: Expand test suite with each phase
- **Documentation**: Keep DEVELOPMENT_GUIDE.md and docs up-to-date

---

## Status Tracking

| Phase | Version | Status | Timeline |
|-------|---------|--------|----------|
| Current Release | v1.0.6 | 🟡 In Review | - |
| Phase 1 | v1.1 | ⏳ Planned | After v1.0.6 approval |
| Phase 2 | v1.2 | ⏳ Planned | After v1.1 launch |
| Future | v1.3+ | 📋 Backlog | TBD |

---

## Key Metrics to Track

- Android download count and user growth
- Subscription conversion rate
- Retention rate (monthly/annual)
- Revenue per user
- Platform-specific performance metrics
- User satisfaction and feedback

---

**Last Updated**: 2025-12-09
