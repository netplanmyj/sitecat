/// Error and informational messages displayed to users
/// All messages are in English for consistency
class ErrorMessages {
  ErrorMessages._(); // Private constructor

  // ===== Authentication Errors =====
  /// Firebase error code: account-exists-with-different-credential
  static const String accountExistsWithDifferentCredential =
      'This email address is already registered with a different authentication method.';

  /// Firebase error code: invalid-credential
  static const String invalidCredential = 'Invalid credentials.';

  /// Firebase error code: operation-not-allowed
  static const String operationNotAllowed =
      'This authentication method is not enabled.';

  /// Firebase error code: user-disabled
  static const String userDisabled = 'This account has been disabled.';

  /// Firebase error code: user-not-found
  static const String userNotFound = 'User not found.';

  /// Firebase error code: wrong-password
  static const String wrongPassword = 'Incorrect password.';

  /// Firebase error code: invalid-verification-code
  static const String invalidVerificationCode = 'Invalid verification code.';

  /// Firebase error code: invalid-verification-id
  static const String invalidVerificationId = 'Invalid verification ID.';

  /// Firebase error code: network-request-failed
  static const String networkRequestFailed =
      'A network error occurred. Please check your connection.';

  /// Firebase error code: too-many-requests
  static const String tooManyRequests =
      'Too many requests. Please wait a moment and try again.';

  /// Generic authentication error
  static const String authenticationError = 'Authentication failed.';

  // ===== Site Management =====
  static const String siteLimitMessage =
      'Free plan allows up to 3 sites. Upgrade to add more.';

  static const String siteLimitReachedMessage =
      'Site limit reached. Delete an existing site to add a new one.';

  static const String premiumSiteLimitReachedMessage =
      'Site limit reached (30 sites maximum).';

  // ===== Subscription/IAP =====
  static const String failedToLoadSubscriptionInfo =
      'Failed to load subscription information: ';

  static const String failedToCheckAccessRights =
      'Failed to check access rights: ';

  static const String failedToLoadProductDetails =
      'Failed to load product details: ';

  static const String purchaseFailed = 'Purchase failed.';

  static const String purchaseErrorOccurred =
      'An error occurred during purchase: ';

  static const String noRestorablePurchases = 'No restorable purchases found.';

  static const String restoreErrorOccurred =
      'An error occurred during restoration: ';

  // ===== Navigation =====
  static const String confirmEndScanTitle = 'End scan?';

  static const String confirmEndScanMessage =
      'Current progress will be saved to Results. Are you sure?';

  static const String confirmEndScanOkText = 'Save and End';

  static const String confirmEndScanCancelText = 'Cancel';
}
