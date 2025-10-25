# Firebase認証実装 技術仕様書

## 概要
SiteCat無料版B案に基づく Firebase Google認証の技術実装仕様です。

## 1. Firebase プロジェクト設定

### 1.1 Firebase Console設定
```bash
# Firebase CLI インストール
npm install -g firebase-tools

# ログイン
firebase login

# プロジェクト初期化
firebase init

# 選択する機能:
# - Authentication
# - Firestore Database
# - Functions
# - Hosting
```

### 1.2 認証プロバイダー設定
- Google Sign-In を有効化
- 承認済みドメインにアプリのドメインを追加
- OAuth 2.0 クライアント ID の設定

## 2. Flutter依存関係設定

### 2.1 pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase Core
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  cloud_functions: ^4.6.0
  
  # Google Sign-In
  google_sign_in: ^6.1.6
  
  # State Management
  provider: ^6.1.1
  
  # UI
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

### 2.2 プラットフォーム別設定

#### Android (`android/app/build.gradle`)
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-auth'
    implementation 'com.google.android.gms:play-services-auth'
}
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

#### Web (`web/index.html`)
```html
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-app.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-auth.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-firestore.js"></script>
```

## 3. 認証サービス実装

### 3.1 Firebase初期化
```dart
// lib/firebase_options.dart (自動生成)
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // プラットフォーム別設定
  }
}

// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

### 3.2 認証サービス
```dart
// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 現在のユーザー取得
  User? get currentUser => _auth.currentUser;
  
  // 認証状態のStream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google サインイン
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google Sign-In フロー
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Firebase認証用の認証情報作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase認証
      final UserCredential userCredential = 
          await _auth.signInWithCredential(credential);
      
      // 初回ログイン時のユーザー作成
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }

  // サインアウト
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ユーザードキュメント作成
  Future<void> _createUserDocument(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    
    await userDoc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'plan': 'free',
      'siteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}
```

## 4. UI実装

### 4.1 認証状態管理
```dart
// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.signInWithGoogle();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
```

### 4.2 ログイン画面
```dart
// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ロゴ
              Icon(
                Icons.pets,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 24),
              
              // タイトル
              Text(
                'SiteCat',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              SizedBox(height: 8),
              
              Text(
                'Website Monitoring Made Easy',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              
              // サインインボタン
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return ElevatedButton.icon(
                    onPressed: authProvider.isLoading 
                        ? null 
                        : () => authProvider.signInWithGoogle(),
                    icon: authProvider.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.login),
                    label: Text(
                      authProvider.isLoading 
                          ? 'Signing in...' 
                          : 'Sign in with Google'
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  );
                },
              ),
              
              SizedBox(height: 24),
              
              // 利用規約・プライバシーポリシー
              Text(
                'By signing in, you agree to our Terms of Service and Privacy Policy',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 4.3 メイン画面（認証後）
```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SiteCat'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthProvider>().signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ユーザー情報
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Icon(Icons.person)
                          : null,
                    ),
                    title: Text(user?.displayName ?? 'Unknown User'),
                    subtitle: Text(user?.email ?? 'No email'),
                    trailing: Chip(
                      label: Text('FREE'),
                      backgroundColor: Colors.green[100],
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
                
                // プレースホルダー：サイト一覧
                Text(
                  'Your Sites',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 16),
                
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.web,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No sites added yet',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add your first site to start monitoring',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: サイト追加画面への遷移
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Site addition coming soon!')),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Add Site',
      ),
    );
  }
}
```

## 5. Firestoreセキュリティルール

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザーコレクション
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // サイトコレクション（次フェーズで詳細実装）
    match /sites/{siteId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
    }
  }
}
```

## 6. テスト仕様

### 6.1 ユニットテスト
```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sitecat/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('should sign in with Google successfully', () async {
      // テスト実装
    });
    
    test('should handle sign-in errors', () async {
      // エラーハンドリングテスト
    });
    
    test('should sign out successfully', () async {
      // サインアウトテスト
    });
  });
}
```

### 6.2 ウィジェットテスト
```dart
// test/screens/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sitecat/screens/login_screen.dart';
import 'package:sitecat/providers/auth_provider.dart';

void main() {
  testWidgets('LoginScreen should display sign-in button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);
  });
}
```

## 7. デプロイメント設定

### 7.1 Firebase設定
```json
{
  "projects": {
    "default": "sitecat-prod"
  }
}
```

### 7.2 CI/CD更新
```yaml
# .github/workflows/ci.yml に追加
- name: Setup Firebase CLI
  run: npm install -g firebase-tools

- name: Deploy Firestore rules
  run: firebase deploy --only firestore:rules
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

## 実装チェックリスト

### 設定
- [ ] Firebase プロジェクト作成
- [ ] 認証プロバイダー設定
- [ ] プラットフォーム別設定ファイル配置
- [ ] pubspec.yaml 依存関係追加

### 実装
- [ ] Firebase初期化
- [ ] AuthService実装
- [ ] AuthProvider実装
- [ ] LoginScreen実装
- [ ] HomeScreen実装
- [ ] 認証フロー確認

### テスト
- [ ] ユニットテスト実装
- [ ] ウィジェットテスト実装
- [ ] 統合テスト実行
- [ ] 全プラットフォームでの動作確認

### セキュリティ
- [ ] Firestoreセキュリティルール適用
- [ ] 認証トークンの適切な管理
- [ ] エラー情報の適切な処理

この仕様書に基づいて実装することで、セキュアで拡張可能なFirebase認証システムを構築できます。