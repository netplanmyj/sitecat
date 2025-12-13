# GitHub Copilot Instructions for SiteCat

## Project Overview
SiteCat is an iOS-first Flutter app for website monitoring and broken link detection. It uses Firebase for backend (Auth, Firestore, Functions) and implements a freemium IAP model (¥1,200 lifetime).

**Current Status**: v1.0.8 (Build 76) - App Store live in 175 countries, 168 tests passing

## Architecture Overview: Provider Pattern + Modular Services

**Critical Data Flow**: `Screen → Consumer<Provider> → Provider → Service → Firestore`

```
lib/
├── screens/              # UI only - display data via Consumer<Provider>
├── providers/            # State mgmt (5 files): auth, site, monitoring, link_checker, subscription
├── services/             # Business logic
│   ├── auth_service.dart
│   ├── site_service.dart              # Firestore CRUD, URL validation
│   ├── monitoring_service.dart        # HTTP health checks (10s timeout)
│   ├── subscription_service.dart      # StoreKit 2 IAP, premium status
│   ├── cooldown_service.dart          # Rate limiting (10s between checks)
│   └── link_checker/                  # Modular split (8 files)
│       ├── scan_orchestrator.dart     # Isolate-based orchestration
│       ├── sitemap_parser.dart        # XML/HTML parsing
│       ├── link_extractor.dart        # Extract href from HTML
│       ├── link_validator.dart        # HTTP HEAD/GET validation
│       ├── http_client.dart           # Parallel requests (~10 concurrent)
│       ├── result_builder.dart        # Build LinkCheckResult objects
│       ├── result_repository.dart     # Save to Firestore
│       └── models.dart                # Type definitions
├── models/               # Firestore data classes (fromFirestore/toFirestore)
└── widgets/              # Reusable UI (13+ shared components)
```

### Architecture Rules (STRICTLY ENFORCE)

1. **Screens**: UI only. NEVER put HTTP calls or Firestore operations here. Use `Consumer<Provider>` to read state.
2. **Providers**: State bridge. Call service methods, update state via `notifyListeners()`, manage UI state flags (`_isLoading`, `_error`).
3. **Services**: All I/O (Firebase, HTTP). Return Streams for realtime data, Futures for one-off operations. No UI dependencies.
4. **Models**: Data structs with `fromFirestore()`/`toFirestore()` and `copyWith()`. Minimal logic.

**Real Pattern - Create Site:**
```dart
// Screen calls Provider
await Provider.of<SiteProvider>(context, listen: false).createSite(url);

// Provider orchestrates
Future<void> createSite(String url) async {
  _isLoading = true;
  notifyListeners();
  try {
    await _siteService.validateUrl(url);     // May throw ValidationException
    await _siteService.createSite(url);      // Saves to Firestore
    // Stream listener auto-updates _sites from Firestore
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// Service (no UI knowledge)
Future<void> createSite(String url) async {
  final site = Site(url: url, ...);
  await _sitesCollection(_currentUserId!).add(site.toFirestore());
}

// ❌ WRONG: Direct Firestore in Provider/Screen
// ❌ WRONG: UI logic in Service
// ❌ WRONG: Future instead of Stream for realtime data
```

**Stream Pattern (Realtime Updates):**
```dart
// Service returns Stream for auto-sync
Stream<List<Site>> getUserSites() {
  return _sitesCollection(_currentUserId!)
    .orderBy('createdAt', descending: true)
    .snapshots()
    .map((snap) => snap.docs.map(Site.fromFirestore).toList());
}

// Provider subscribes in initialize()
void initialize(String userId) {
  _sitesSubscription = _siteService.getUserSites().listen((sites) {
    _sites = sites;
    notifyListeners();  // UI automatically updates
  });
}
```

## Development Workflow

### Before Every PR (Run Locally) - MANDATORY
```bash
# This MUST pass before creating a PR - CI will block merge otherwise
flutter analyze                              # Lint check (must pass)
dart format --set-exit-if-changed .          # Format (must pass)  
flutter test                                 # All 168 tests (must pass)

# One-liner (recommended)
flutter analyze && dart format --set-exit-if-changed . && flutter test
```

**Why These Matter**:
- `flutter analyze`: Detects lint errors, type issues, dead code (configured in `analysis_options.yaml`)
- `dart format`: Enforces consistent code style across team
- `flutter test`: Prevents regressions (currently 168 tests, targeting 50%+ coverage)

### CI/CD Pipeline
- **GitHub Actions** (`ci.yml`): Runs on every PR to `main` - auto-runs analyze, format, test. **PR merge BLOCKED if any step fails**.
- **Xcode Cloud** (`release-ios.yml`): Triggered on version tag push (`v*`), builds TestFlight release
- Format/analyze failures are merge blockers - fix locally before pushing

### Git Workflow (Strict)
- `main`: Production only (App Store releases + tag releases)
- `feature/*`: Feature branches from `main`
- `hotfix/*`: Critical fixes from `main`
- **NEVER** push directly to `main` - always PR
- PR must have approvals + all CI checks passing

### Testing Strategy (32% → 50%+ Target)
- **Unit Tests**: Business logic in services (e.g., site validation, URL parsing)
- **Provider Tests**: State management and data binding (critical for PR #264-267)
- **Widget Tests**: UI components rendering with different states
- **Mock Pattern**: Use `fake_cloud_firestore` + `firebase_auth_mocks` (no emulator)
- **File Pattern**: `test/<mirror_lib_structure>/*_test.dart`
- **Mockito**: For generating mocks - run `dart run build_runner build` after changes

## Critical Implementation Patterns

### 1. Hierarchical Firestore Structure with User Scoping
```dart
// ✅ CORRECT: All data nested under user
/users/{userId}/
  ├── sites/{siteId}                    # User's sites
  ├── monitoringResults/{resultId}      # Site health checks
  └── linkCheckResults/{checkId}        # Link validation results

// Service pattern (NOT in Provider/Screen)
String? get _currentUserId => _auth.currentUser?.uid;
CollectionReference _sitesCollection(String userId) =>
    _firestore.collection('users').doc(userId).collection('sites');

// Always check auth before accessing:
if (_currentUserId == null) throw Exception('User must be authenticated');
```

### 2. Realtime Streams for Data Sync (NOT Futures)
```dart
// ✅ Use Stream for auto-update when Firestore data changes
Stream<List<Site>> getUserSites() {
  return _sitesCollection(_currentUserId!)
    .orderBy('createdAt', descending: true)
    .snapshots()
    .map((snap) => snap.docs.map(Site.fromFirestore).toList());
}

// ❌ Avoid: Fetching once with Future
Future<List<Site>> loadSites() => ... // Works but requires manual refresh
```

### 3. Cooldown & Rate Limiting (Always via CooldownService)
```dart
// Service-level rate limiting
static const Duration checkInterval = Duration(seconds: 10);  // Minimum time between checks

// Provider checks before allowing action
Duration? getTimeUntilNextCheck(String siteId) {
  return _cooldownService.getTimeUntilNextCheck(siteId);
}

bool canCheckSite(String siteId) {
  return getTimeUntilNextCheck(siteId) == null;
}

// UI disables button if cooldown active
ElevatedButton(
  onPressed: provider.canCheckSite(siteId) ? () => provider.checkSite(siteId) : null,
  child: Text(provider.canCheckSite(siteId) 
    ? 'Check Now' 
    : 'Check in ${provider.getTimeUntilNextCheck(siteId)?.inSeconds}s'),
)
```

### 4. Premium Feature Gates (via SubscriptionProvider)
```dart
// Constants defined in AppConstants
static const int freePlanSiteLimit = 3;      // Free users can add 3 sites
static const int premiumSiteLimit = 30;      // Premium: 30 sites (practical limit)
static const int freeHistoryLimit = 10;      // Keep 10 monitoring results
static const int premiumHistoryLimit = 50;   // Keep 50 for premium

// In Provider, check subscription status
bool get canAddSite {
  final subscription = Provider.of<SubscriptionProvider>(context);
  if (subscription.hasLifetimeAccess) {
    return sites.length < AppConstants.premiumSiteLimit;
  }
  return sites.length < AppConstants.freePlanSiteLimit;
}

// Services respect history limits (auto-cleanup)
void setHistoryLimit(bool isPremium) {
  _historyLimit = isPremium ? premiumHistoryLimit : freeHistoryLimit;
}
```

### 5. Link Checker Module (Complex, Modular System)
**Location**: `lib/services/link_checker/` (8 files)

**Orchestration**: `scan_orchestrator.dart` manages Isolate-based background processing for site scans.

**Key Pattern**: Scan can be paused/resumed by persisting `lastScannedPageIndex` on the `Site` model and using the `continueFromLastScan` parameter in `checkSiteLinks`:
```dart
// Site model stores last scanned page index
class Site {
  int lastScannedPageIndex;
  // ... other fields ...
}

// Provider triggers scan, passing lastScannedPageIndex
Future<void> startOrResumeScan(Site site) async {
  await linkCheckerService.checkSiteLinks(
    siteId: site.id,
    continueFromLastScan: site.lastScannedPageIndex,
  );
}

// Service method continues scan from last index
Future<LinkCheckResult> checkSiteLinks({
  required String siteId,
  required int continueFromLastScan,
}) async {
  for (int i = continueFromLastScan; i < totalPages; i++) {
    // Process page i
    // Update lastScannedPageIndex in Site model as needed
  }
  // Return result
}
```

**When modifying link_checker**:
- Do NOT move/rename files without updating imports in all services
- Preserve sitemap parsing patterns (XML + HTML fallback)
- Keep 8-file modular structure (don't merge into fewer files)
- Respect Isolate isolation - services must be stateless for background execution

## Code Quality Standards

### Refactoring Policy (CRITICAL)
- **Files > 1000 lines**: 🔴 MUST split immediately
- **Files 500-999 lines**: 🟡 Split in next version
- **Files 200-499 lines**: 🟢 Extract methods if needed
- **Delete unused code immediately** - no "later" deletions
- Document metrics in `docs/REFACTORING_METRICS.md`

### Naming Conventions
- Variables/functions: camelCase (English)
- Classes: PascalCase
- Private members: `_prefixWithUnderscore`
- Comments: Japanese OK, but code names in English

### Code Organization
```dart
class MyProvider extends ChangeNotifier {
  // 1. Dependencies (inject in constructor)
  final MyService _service;
  
  // 2. State variables (private)
  List<Item> _items = [];
  bool _isLoading = false;
  
  // 3. Getters (public interface)
  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  
  // 4. Public methods
  Future<void> loadItems() async { ... }
  
  // 5. Private helpers
  void _handleError(String message) { ... }
}
```

## Firebase Configuration

### Production vs Dev
- **Native files**: `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- **Dart config**: Debug builds use `firebase_options_dev.dart` (development Firebase project), release/profile builds use `firebase_options_prod.dart` (production Firebase project), selected automatically via `kReleaseMode` in `lib/firebase_options.dart`
- **CI workaround**: Uses `lib/firebase_options.dart.example` for CI builds

### Security Rules
- Users can only access their own data: `/users/{userId}/**`
- Sites nested under users for automatic scope enforcement

## Common Tasks

### Adding a New Feature
1. Create model in `lib/models/`
2. Add service in `lib/services/` (business logic + Firebase)
3. Create provider in `lib/providers/` (state management)
4. Build UI in `lib/screens/` using `Consumer<Provider>`
5. Write tests in `test/` mirroring lib structure
6. Run `flutter analyze && dart format --set-exit-if-changed . && flutter test`

### Updating a Model
1. Update `lib/models/[model].dart` - add fields with defaults
2. Update `fromFirestore()` / `toFirestore()` methods
3. Update `copyWith()` method
4. Add migration logic if needed (Firestore auto-handles missing fields)
5. Update related services that use the model
6. Update tests

### Debugging Tips
- Check `analysis_options.yaml` - TODOs are ignored in lint
- Use `Logger` from `package:logger` for debug logs
- Firebase emulator NOT used - always test against dev project
- iOS simulator required for full testing (StoreKit 2 IAP)

## Documentation

Related documentation files in the `docs/` folder:
- `DEVELOPMENT_GUIDE.md` - Full architecture, refactoring plan, roadmap
- `PROJECT_CONCEPT.md` - Business goals, feature specs
- `REFACTORING_PLAN.md` - Active refactoring tasks and metrics

## Key Dependencies (pubspec.yaml)
- `firebase_*`: Auth, Firestore, Functions
- `provider: ^6.1.2`: State management
- `http: ^1.2.2`: REST calls for monitoring
- `html: ^0.15.5` / `xml: ^6.5.0`: Sitemap parsing
- `in_app_purchase: ^3.2.1`: StoreKit 2 integration
- `fl_chart: ^0.69.0`: Statistics graphs

## Quick Reference: File Size Monitoring
Run this to find large files needing refactoring:
```bash
find lib -name "*.dart" -exec wc -l {} + | sort -rn | head -10
```

## Anti-Patterns to Avoid
❌ Putting business logic in Screens  
❌ Direct Firestore calls from Providers  
❌ Using Future instead of Stream for realtime data  
❌ Ignoring the layered architecture  
❌ Skipping `flutter analyze` before PR  
❌ Creating 1000+ line "god classes"  
❌ Leaving dead code "for later"  

## Language Note
- UI text: Japanese (target market)
- Code/comments: Mix of English/Japanese OK
- Commit messages: English preferred
- Documentation: Japanese in docs/, English in code comments

## For AI Coding Agents: Critical Integration Points

### Provider Injection & Dependency Injection
All providers and services accept optional mocks in constructors for testability:
```dart
class SiteProvider extends ChangeNotifier {
  SiteProvider({
    SiteService? siteService,
    SubscriptionService? subscriptionService,
  }) : _siteService = siteService ?? SiteService(),
       _subscriptionService = subscriptionService ?? SubscriptionService();
}
```
When writing tests or refactoring, pass mock implementations to enable isolated testing.

### Firebase Options & CI/CD Integration
- **Development**: Uses `firebase_options_dev.dart` 
- **Production**: Uses `firebase_options_prod.dart`
- **CI/CD**: Copies `firebase_options.dart.example` → `firebase_options.dart` to avoid exposing real credentials
- **When adding Firebase features**: Update both dev and prod configs, ensure CI still passes

### Site Scan Flow (Multi-Step Async Operation)
The link checker is one of the most complex flows in the app:
1. `LinkCheckerProvider.startScan(siteId)` triggers orchestration
2. `LinkCheckerService` calls `ScanOrchestrator.scan()` with Isolate isolation
3. Isolate spawns background process to parse sitemap, extract links, validate
4. Results stream back via Stream subscription with progress updates
5. `LinkCheckerProvider.pauseScan()` / `.resumeScan()` manage state by persisting `_lastScannedPageIndex`

**When modifying**: Ensure Stream cleanup in provider's `dispose()`, handle Isolate errors gracefully, preserve progress state.

### Test Mocking Strategy
Use these packages (already in pubspec.yaml):
- `fake_cloud_firestore`: Mock Firestore collections and documents
- `firebase_auth_mocks`: Mock FirebaseAuth user state  
- `mockito`: Generate service mocks with `@GenerateMocks()` decorator

Example:
```dart
@GenerateMocks([SiteService])
void main() {
  test('Provider handles network error', () async {
    final mockService = MockSiteService();
    when(mockService.createSite(...)).thenThrow(Exception('Network error'));
    
    final provider = SiteProvider(siteService: mockService);
    await provider.createSite(...);
    
    expect(provider.error, contains('Network error'));
  });
}
```

### Model Serialization Expectations
All models (Site, MonitoringResult, BrokenLink, etc.) MUST implement:
- `fromFirestore()`: Convert Firestore DocumentSnapshot → Dart object
- `toFirestore()`: Convert Dart object → Map<String, dynamic> for Firestore storage
- `copyWith()`: Immutable updates (used extensively in providers for state changes)

Example from Site model:
```dart
factory Site.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Site(
    id: doc.id,
    url: data['url'] as String,
    excludedPaths: List<String>.from(data['excludedPaths'] ?? []),
    // ... other fields with null-safety defaults
  );
}

Map<String, dynamic> toFirestore() {
  return {
    'url': url,
    'excludedPaths': excludedPaths,
    // ...
  };
}
```

### Key Constants Location
All magic numbers/strings live in `lib/constants/app_constants.dart`:
```dart
static const int freePlanSiteLimit = 3;
static const int premiumSiteLimit = 30;
static const int freeHistoryLimit = 10;
static const int premiumHistoryLimit = 50;
```
Never hardcode these values - always reference the constant.

**Note**: Cooldown intervals are defined in providers:
- `MonitoringProvider.minimumCheckInterval`: 10 seconds
- `LinkCheckerProvider.defaultCooldown`: 10 seconds

### Error Handling Pattern
Providers catch service errors and convert to user-facing messages:
```dart
try {
  await _service.someOperation();
} catch (e) {
  _error = _formatErrorMessage(e);  // Convert technical error to UI message
  notifyListeners();
  rethrow;  // Allow caller to handle if needed
}
```

### Hot Reload Considerations
- Models with `copyWith()` are safe to reload
- Provider state persists across hot reload (be aware during development)
- Services are singletons - test if pooling/resource cleanup is needed
- **Always**: Test on physical device or emulator before pushing (UI glitches may not appear in hot reload)
