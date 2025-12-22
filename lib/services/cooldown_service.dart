/// Manages cooldown periods to enforce rate limiting between operations
abstract class CooldownService {
  /// Check if an action can be performed for the given siteId
  bool canPerformAction(String siteId);

  /// Get remaining time until next action is allowed, or null if action can proceed
  Duration? getTimeUntilNextCheck(String siteId);

  /// Start a cooldown period for the given siteId
  void startCooldown(String siteId, Duration duration);

  /// Get all currently active cooldowns (returned as unmodifiable map)
  Map<String, DateTime> get activeCooldowns;

  /// Clear cooldown for a specific siteId
  void clearCooldown(String siteId);

  /// Clear all cooldowns
  void clearAll();
}

/// Default in-memory implementation of CooldownService with lazy cleanup
class DefaultCooldownService implements CooldownService {
  final Map<String, DateTime> _nextAllowedAt = {};

  @override
  bool canPerformAction(String siteId) => getTimeUntilNextCheck(siteId) == null;

  @override
  Duration? getTimeUntilNextCheck(String siteId) {
    final now = DateTime.now();

    // Lazy cleanup: Remove ALL expired entries to prevent memory leaks
    _cleanupExpiredEntries();

    final next = _nextAllowedAt[siteId];
    if (next == null || now.isAfter(next)) return null;
    return next.difference(now);
  }

  /// Remove all expired cooldown entries (lazy cleanup strategy)
  /// Called periodically via getTimeUntilNextCheck() to avoid memory accumulation
  void _cleanupExpiredEntries() {
    final now = DateTime.now();
    _nextAllowedAt.removeWhere((_, expiry) => now.isAfter(expiry));
  }

  @override
  void startCooldown(String siteId, Duration duration) {
    _nextAllowedAt[siteId] = DateTime.now().add(duration);
  }

  @override
  Map<String, DateTime> get activeCooldowns => Map.unmodifiable(_nextAllowedAt);

  @override
  void clearCooldown(String siteId) {
    _nextAllowedAt.remove(siteId);
  }

  @override
  void clearAll() {
    _nextAllowedAt.clear();
  }
}
