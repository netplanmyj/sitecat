# GitHub Copilot Instructions for SiteCat

## Project Overview
SiteCat is an iOS-first Flutter app for website monitoring and broken link detection. It uses Firebase for backend (Auth, Firestore, Functions) and implements a freemium IAP model (¥1,200 lifetime).

**Current Status**: v1.0.9 (Build 77) - App Store live in 175 countries, 409 tests passing, 7 providers, 8 services

**Key Facts**:
- **Language**: Flutter/Dart (3.35.7+ stable), iOS-only deployment
- **Backend**: Firebase (dual environment: sitecat-dev / sitecat-prod)
- **State Management**: Provider pattern (ChangeNotifier)
- **Testing**: 409 tests with fake_cloud_firestore + firebase_auth_mocks
- **CI/CD**: GitHub Actions (analyze/format/test) + Xcode Cloud (releases)

## Architecture Overview: Provider Pattern + Modular Services

**Critical Data Flow**: `Screen → Consumer<Provider> → Provider → Service → Firestore`

```
lib/
├── screens/              # UI only - display data via Consumer<Provider>
├── providers/            # State mgmt (7 files): auth, site, monitoring, link_checker, link_checker_progress, link_checker_cache, subscription
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
flutter test                                 # All 409 tests (must pass)

# One-liner (recommended)
flutter analyze && dart format --set-exit-if-changed . && flutter test
```

**Why These Matter**:
- `flutter analyze`: Detects lint errors, type issues, dead code (configured in `analysis_options.yaml` - TODOs ignored)
- `dart format`: Enforces consistent code style across team
- `flutter test`: Prevents regressions (currently 409 tests passing)
- **CI Requirement**: All three MUST pass or PR will be blocked from merging

**Common Fix Flow**:
```bash
# If analyze fails
flutter analyze  # Read errors
# Fix issues in code
flutter analyze  # Verify

# If format fails
dart format .    # Auto-format all files
git add -A && git commit -m "chore: format code"

# If tests fail
flutter test     # See which tests failed
# Fix the code or update tests
flutter test     # Verify
```

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
- **Current Coverage**: 409 tests passing across all layers

**Test Execution**:
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/site_service_test.dart

# Run with coverage
flutter test --coverage

# Generate mocks (after adding @GenerateMocks annotation)
dart run build_runner build
```

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

**Key Constants Location**
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

### Firebase Environment Pattern (CRITICAL)
**Development vs Production Switching**:
```dart
// lib/firebase_options.dart - Auto-selects environment
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kReleaseMode) {
      return prod.DefaultFirebaseOptions.currentPlatform;  // Production
    }
    return dev.DefaultFirebaseOptions.currentPlatform;     // Development
  }
}

// Usage in main.dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Testing Different Environments**:
```bash
# Debug build (uses sitecat-dev)
flutter run

# Profile build (uses sitecat-dev, with performance profiling)
flutter run --profile

# Release build (uses sitecat-prod)
flutter run --release
```

**CI/CD Firebase Options**:
- CI uses `firebase_options.dart.example` (copied to `firebase_options.dart` during build)
- Never commit real Firebase credentials to git
- Dev/Prod credentials live in separate files: `firebase_options_dev.dart`, `firebase_options_prod.dart`

**Backend Deployment**:
```bash
# Deploy to development
firebase deploy --only functions --project sitecat-dev
firebase deploy --only firestore:rules --project sitecat-dev

# Deploy to production
firebase deploy --only functions --project sitecat-prod
firebase deploy --only firestore:rules --project sitecat-prod
```

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

## Common Refactoring Patterns (Real Scenarios in SiteCat)

### Pattern 1: Splitting Overgrown Providers (LinkCheckerProvider 554 lines → Progressive Split)
**Scenario**: Provider manages too many responsibilities - UI state, caching, progress tracking, demo mode

**Example from SiteCat**:
```dart
// ❌ BEFORE: All responsibilities in one Provider
class LinkCheckerProvider extends ChangeNotifier {
  final Map<String, LinkCheckState> _checkStates = {};
  final Map<String, String> _errors = {};
  final Map<String, LinkCheckResult?> _cachedResults = {};  // Cache logic mixed in
  final Map<String, (int, int)> _progressTracking = {};     // Progress mixed in
  final Map<String, bool> _demoMode = {};                    // Demo state mixed in
  
  // 50+ methods handling all concerns
}

// ✅ AFTER: Delegated to specialized classes (already done in SiteCat!)
class LinkCheckerProvider extends ChangeNotifier {
  final LinkCheckerCache _cache;        // Separate cache management
  final LinkCheckerProgress _progress;  // Separate progress tracking
  
  LinkCheckerProvider({
    LinkCheckerCache? cache,
    LinkCheckerProgress? progress,
  }) : _cache = cache ?? LinkCheckerCache(),
       _progress = progress ?? LinkCheckerProgress();
       
  LinkCheckResult? getCachedResult(String siteId) => _cache.getResult(siteId);
  (int, int) getProgress(String siteId) => 
    (_progress.getCheckedCount(siteId), _progress.getTotalCount(siteId));
}
```

**Apply this pattern when**:
- Provider has 400+ lines with multiple state management concerns
- Multiple unrelated state variables (cache, progress, UI state, config)
- Testing requires mocking different aspects independently

**Extraction steps**:
1. Identify cohesive state groups (cache, progress, errors, UI flags)
2. Create specialized classes with single responsibility
3. Use constructor injection for testability
4. Provider delegates to these classes via getters/setters
5. Update all dependent Screens to use new API
6. Update tests to mock new classes

### Pattern 2: Service Module Extraction (LinkCheckerService 461 lines → 8 specialized files)
**Scenario**: Service handles multiple domain concerns - orchestration, parsing, validation, HTTP, storage

**Example from SiteCat**:
```dart
// ❌ BEFORE: Monolithic service
class LinkCheckerService {
  // HTTP client concerns (100 lines)
  Future<Response> checkLink(String url) { ... }
  
  // Sitemap parsing (120 lines)
  Future<List<String>> parseSitemap(String url) { ... }
  
  // Link validation (150 lines)
  Future<List<BrokenLink>> validateLinks(List<String> urls) { ... }
  
  // Firestore operations (80 lines)
  Future<void> saveResults(LinkCheckResult result) { ... }
}

// ✅ AFTER: Modular service hierarchy (already done in SiteCat!)
lib/services/link_checker/
├── http_client.dart        # HTTP concerns only
├── sitemap_parser.dart     # Parsing logic
├── link_extractor.dart     # Link discovery
├── link_validator.dart     # Validation logic
├── result_builder.dart     # Result construction
├── result_repository.dart  # Firestore operations
├── scan_orchestrator.dart  # Orchestration (Isolate)
└── models.dart             # Type definitions

// Main service becomes an orchestrator
class LinkCheckerService implements LinkCheckerClient {
  late final LinkCheckerHttpClient _httpHelper;
  late final SitemapParser _sitemapParser;
  late final ScanOrchestrator _orchestrator;
  late final LinkExtractor _extractor;
  late final ResultBuilder _resultBuilder;
  LinkCheckResultRepository? _repository;
  
  // Delegates to specialized components
  Future<LinkCheckResult> checkSiteLinks(Site site, {...}) async {
    final urls = await _orchestrator.scan(site);
    return _resultBuilder.build(urls);
  }
}
```

**Apply this pattern when**:
- Service file > 500 lines with distinct functional domains
- Different parts require independent testing
- Cross-cutting concerns like HTTP, parsing, storage mixed together

**Extraction steps**:
1. Identify functional domains (HTTP, parsing, validation, storage, orchestration)
2. Create specialized class for each domain with single interface
3. Extract related methods and their dependencies
4. Create abstract interfaces for dependency injection
5. Main service becomes thin orchestrator delegating to specialized classes
6. Each class independently testable with mocks
7. Update provider to inject mocked versions in tests

### Pattern 3: Model Serialization Consolidation (Avoiding Duplication)
**Scenario**: Multiple models share similar `fromFirestore()`/`toFirestore()` patterns

**Example from SiteCat** (apply to new models):
```dart
// ❌ BEFORE: Duplicated serialization logic
class Site {
  factory Site.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Site(
      id: doc.id,
      url: data['url'] as String,
      excludedPaths: List<String>.from(data['excludedPaths'] ?? []),
      lastScannedPageIndex: data['lastScannedPageIndex'] as int? ?? 0,
      // ... 20 more fields with repetitive null-coalescing
    );
  }
}

class MonitoringResult {
  factory MonitoringResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MonitoringResult(
      id: doc.id,
      siteId: data['siteId'] as String,
      status: data['status'] as int? ?? 0,
      // ... same pattern repeated
    );
  }
}

// ✅ AFTER: Extract to mixin or base class
mixin FirestoreSerializable {
  T get<T>(Map<String, dynamic> data, String key, {T? defaultValue}) {
    return (data[key] as T?) ?? (defaultValue as T);
  }
  
  List<T> getList<T>(Map<String, dynamic> data, String key, {List<T>? defaultValue}) {
    return List<T>.from(data[key] as List? ?? defaultValue ?? []);
  }
}

class Site with FirestoreSerializable {
  factory Site.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Site(
      id: doc.id,
      url: get<String>(data, 'url'),
      excludedPaths: getList<String>(data, 'excludedPaths'),
      lastScannedPageIndex: get<int>(data, 'lastScannedPageIndex', defaultValue: 0),
    );
  }
}
```

**Apply this pattern when**:
- Multiple models have `fromFirestore()` boilerplate
- Null-coalescing and type casting duplicated across models
- Changes to serialization strategy require updating many files

### Pattern 4: State Management Separation (Cache + Progress Providers)
**Scenario**: Provider UI state mixed with caching and progress tracking

**Pattern implementation**:
```dart
// Separate concern: Cache management (plain data holder)
class LinkCheckerCache {
  final Map<String, LinkCheckResult> _results = {};
  final Map<String, List<BrokenLink>> _brokenLinks = {};
  
  LinkCheckResult? getResult(String siteId) => _results[siteId];
  void setResult(String siteId, LinkCheckResult result) {
    _results[siteId] = result;
  }
  void clear(String siteId) {
    _results.remove(siteId);
    _brokenLinks.remove(siteId);
  }
}

// Separate concern: Progress tracking (plain data holder)
class LinkCheckerProgress {
  final Map<String, int> _checkedCounts = {};
  final Map<String, int> _totalCounts = {};
  final Map<String, bool> _processingExternal = {};
  
  int getCheckedCount(String siteId) => _checkedCounts[siteId] ?? 0;
  void setProgress(String siteId, int checked, int total) {
    _checkedCounts[siteId] = checked;
    _totalCounts[siteId] = total;
  }
}

// Provider focuses on UI state, notifications, and coordination
class LinkCheckerProvider extends ChangeNotifier {
  final LinkCheckerCache _cache;
  final LinkCheckerProgress _progress;
  final Map<String, LinkCheckState> _checkStates = {}; // UI only
  
  // LinkCheckerProvider calls notifyListeners() after delegating to cache/progress
  // Screen watches LinkCheckerProvider for UI state changes and derived cache/progress data
}
```

**Benefits**:
- Screen widgets can be more granular listeners
- Cache updates don't trigger UI state re-renders
- Progress updates don't reload cached data
- Testing each concern independently
- Performance: Fine-grained reactivity

### Pattern 5: Extracting Constants and Magic Numbers
**Scenario**: Magic numbers spread across code, making premium feature gates hard to manage

**Current SiteCat pattern** (already implemented):
```dart
// ✅ GOOD: Centralized in AppConstants
class AppConstants {
  AppConstants._(); // Private constructor
  
  // Feature limits
  static const int freePlanSiteLimit = 3;
  static const int premiumSiteLimit = 30;
  
  static const int freePlanPageLimit = 200;
  static const int premiumPlanPageLimit = 1000;
  
  static const int freePlanHistoryLimit = 10;
  static const int premiumHistoryLimit = 50;
  
  // Business logic
  static const Duration minimumCheckInterval = Duration(seconds: 10);
  static const Duration checkTimeout = Duration(seconds: 10);
}

// Usage in Services
class LinkCheckerService {
  int _pageLimit = AppConstants.freePlanPageLimit;
  int _historyLimit = AppConstants.freePlanHistoryLimit;
  
  void setPageLimit(bool isPremium) {
    _pageLimit = isPremium 
      ? AppConstants.premiumPlanPageLimit 
      : AppConstants.freePlanPageLimit;
    // Recreate orchestrator with new limit
    _orchestrator = ScanOrchestrator(pageLimit: _pageLimit);
  }
}
```

**Apply this pattern when**:
- Same number appears in 2+ files (duplicate business rule)
- Constants represent feature gates or business logic
- Changing a value requires updating multiple files

### Pattern 6: Lazy Initialization with Repository Pattern (Already in SiteCat!)
**Scenario**: Service needs to maintain Firestore repository but only for authenticated users

**Implementation from SiteCat**:
```dart
// ❌ BEFORE: Create repository in constructor (fails for unauthenticated users)
class LinkCheckerService {
  late LinkCheckResultRepository _repository;
  
  LinkCheckerService() {
    _repository = LinkCheckResultRepository(userId: _auth.currentUser!.uid);
    // ❌ Crashes if user not logged in yet
  }
}

// ✅ AFTER: Lazy initialization with caching
class LinkCheckerService {
  LinkCheckResultRepository? _repository;
  String? _repositoryUserId;
  
  // Lazy getter - only creates when first accessed
  LinkCheckResultRepository get _repo {
    final userId = _currentUserId!; // Checked at access time
    if (_repository == null || _repositoryUserId != userId) {
      _repositoryUserId = userId;
      _repository = LinkCheckResultRepository(
        firestore: _firestore,
        userId: userId,
        historyLimit: _historyLimit,
      );
    }
    return _repository!;
  }
  
  String? get _currentUserId => _auth.currentUser?.uid;
}
```

**Benefits**:
- Safe for unauthenticated users (repo not created until needed)
- Automatically recreates if user logs out/in (different userId)
- Single source of truth for userId validation
- Testable: Can pass mock repository in constructor

### Pattern 7: Widget Decomposition (Screen/Widget Splitting - Critical for UI Maintainability)
**Scenario**: Screen/Widget file grows too large with mixed concerns - form logic, validation UI, error handling, multiple sections

**Real Example from SiteCat** (site_form_screen.dart refactoring):
```dart
// ❌ BEFORE (historical, pre-refactor): 780 lines - everything in one file
// (Current file after refactoring: 257 lines)
class SiteFormScreen extends StatefulWidget {
  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  // Form state (50+ lines)
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  // ...
  
  // Site limit UI (80 lines)
  Widget _buildSiteLimitUI() { ... }
  
  // Form fields (150 lines)
  Widget _buildNameField() { ... }
  Widget _buildUrlField() { ... }
  
  // Action buttons (60 lines)
  Widget _buildActionButtons() { ... }
  
  // Warning dialogs (100 lines)
  Widget _buildUrlChangeWarning() { ... }
  
  // Excluded paths section (200 lines)
  Widget _buildExcludedPathsEditor() { ... }
  
  // Main build method (200 lines)
  @override
  Widget build(BuildContext context) { ... }
}

// ✅ AFTER: 257 lines + 7 separate widgets = ~650 lines total (16% reduction in main file)
lib/widgets/site_form/
├── site_form_body.dart          # Main form layout (105 lines)
├── site_form_fields.dart        # Input fields (80 lines)
├── site_limit_card.dart         # Site limit UI (65 lines)
├── action_buttons.dart          # Save/Cancel buttons (45 lines)
├── url_change_warning_dialog.dart  # Warning modal (70 lines)
├── excluded_paths_editor.dart   # Path management (110 lines)
└── warning_item.dart            # Single warning item (30 lines)

// Main screen becomes thin orchestrator (current state: 257 lines)
class SiteFormScreen extends StatefulWidget {
  final Site? site;
  const SiteFormScreen({super.key, this.site});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  // Only core form state
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _sitemapUrlController = TextEditingController();
  final _newPathController = TextEditingController();
  late List<String> _excludedPaths;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Check site limit first
    if (_siteCountReachedLimit(context)) {
      return Scaffold(
        appBar: AppBar(),
        body: SiteLimitCard(
          siteCount: _currentSiteCount,
          siteLimit: _siteLimit,
          onBackPressed: () => Navigator.pop(context),
        ),
      );
    }

    // Main form
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Site' : 'Add Site')),
      body: SiteFormBody(
        formKey: _formKey,
        nameController: _nameController,
        urlController: _urlController,
        sitemapUrlController: _sitemapUrlController,
        newPathController: _newPathController,
        excludedPaths: _excludedPaths,
        isEdit: widget.isEdit,
        editingSite: widget.site,
        onAddPath: _addExcludedPath,
        onRemovePath: _removeExcludedPath,
      ),
      bottomNavigationBar: ActionButtons(
        isLoading: _isLoading,
        onSave: _handleSave,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}

// Helper widget (reusable in SiteFormBody)
class SiteFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController urlController;
  final VoidCallback onUrlChanged;
  // ...
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(/* name field */),
        TextFormField(/* url field */)
      ],
    );
  }
}
```

**Widget分割の基準**:

| 基準 | 判断 | 例 |
|------|------|-----|
| **行数** | 200行以上 → 分割検討 | form_body.dart (105行) - OK |
| **責務** | 複数の関心事混在 | 形式フィールド + 警告UI + パス管理 |
| **再利用性** | 他の画面で再利用可能か | SiteLimitCard, ActionButtons は再利用 |
| **テスト** | 単体テスト困難か | ネストしたビルドメソッドは難しい |
| **複雑さ** | 条件分岐やループが多い | 除外パスエディタ (100行) - 分割 |

**分割の手順**:

1. **機能グループ分析**
   ```dart
   // Identify sections
   - Site limit check (60 lines)
   - Form fields (80 lines)
   - Action buttons (40 lines)
   - Excluded paths editor (110 lines)
   - Warning dialogs (70 lines)
   ```

2. **ウィジェット作成 (小さいものから)**
   - `SiteLimitCard` - 単純な表示ウィジェット
   - `ActionButtons` - ボタングループ
   - `WarningItem` - リスト項目
   - `ExcludedPathsEditor` - 複雑ロジック
   - `SiteFormBody` - メインレイアウト

3. **状態・コールバック設計**
   ```dart
   // Parent Screen retains form state
   final _formKey = GlobalKey<FormState>();
   final _nameController = TextEditingController();
   
   // Child widgets receive dependencies & callbacks
   SiteFormBody(
     formKey: _formKey,
     nameController: _nameController,
     onAddPath: _addExcludedPath,
     onRemovePath: _removeExcludedPath,
   )
   ```

4. **Screen 内のロジック保持**
   - 初期化（initState）
   - 状態管理（Provider呼び出し）
   - ナビゲーション制御
   - フォーム検証

5. **Child Widgets は表示に専念**
   - 受け取った値を表示
   - ユーザー入力をコールバックで親に報告
   - 複雑なロジックは避ける

**パターン適用のチェックリスト**:
- ✅ Screen/Widget が200行以上
- ✅ `build()` メソッドが100行以上
- ✅ `_buildXxx()` ヘルパーメソッドが5個以上
- ✅ 同じパターンのUIが繰り返される（リスト項目など）
- ✅ 他の画面で再利用したいウィジェットがある

**禁止パターン**:
```dart
// ❌ AVOID: Child widget が複雑なロジック持つ
class SiteFormBody extends StatefulWidget {  // ← Should be StatelessWidget
  State createState() => _SiteFormBodyState();
}
class _SiteFormBodyState extends State<SiteFormBody> {
  final _formKey = GlobalKey<FormState>();  // ← Logic in child
  Future<void> _save() { ... }  // ← Should call parent callback
}

// ✅ GOOD: Child widget は表示と最小限のUI制御のみ
class SiteFormBody extends StatelessWidget {  // ← Pure presentation
  final GlobalKey<FormState> formKey;  // ← Receives from parent
  final VoidCallback onSave;  // ← Calls parent for logic
}
```

**分割後のテスト戦略**:
```dart
// Each widget individually testable
testWidgets('SiteLimitCard shows lock icon', (tester) async {
  await tester.pumpWidget(SiteLimitCard(
    siteCount: 3,
    siteLimit: 3,
    onBackPressed: () {},
  ));
  expect(find.byIcon(Icons.lock_outline), findsOneWidget);
});

// Parent screen tests form flow
testWidgets('SiteFormScreen validates required fields', (tester) async {
  await tester.pumpWidget(createTestApp(SiteFormScreen()));
  // ... test form validation
});
```
