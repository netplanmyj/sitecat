/// Service for managing cooldown periods between actions
///
/// Used to prevent aggressive API calls by enforcing minimum intervals
/// between actions like site checks or link scans.
class CooldownService {
  final Map<String, DateTime> _cooldownUntil = {};

  /// Start a cooldown period for the given identifier
  ///
  /// [id] - Unique identifier (e.g., siteId)
  /// [duration] - How long the cooldown should last
  void startCooldown(String id, Duration duration) {
    _cooldownUntil[id] = DateTime.now().add(duration);
  }

  /// Check if an action can be performed (not in cooldown)
  ///
  /// Returns true if no cooldown is active or if cooldown has expired
  bool canPerformAction(String id) {
    final cooldownUntil = _cooldownUntil[id];
    if (cooldownUntil == null) return true;

    final now = DateTime.now();
    if (now.isAfter(cooldownUntil)) {
      // Cooldown expired, clean up
      _cooldownUntil.remove(id);
      return true;
    }

    return false;
  }

  /// Get remaining time until action is allowed
  ///
  /// Returns null if no cooldown is active or if cooldown has expired
  Duration? getTimeUntilNextCheck(String id) {
    final cooldownUntil = _cooldownUntil[id];
    if (cooldownUntil == null) return null;

    final remaining = cooldownUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      _cooldownUntil.remove(id);
      return null;
    }

    return remaining;
  }

  /// Clear cooldown for a specific identifier
  void clearCooldown(String id) {
    _cooldownUntil.remove(id);
  }

  /// Clear all cooldowns
  void clearAll() {
    _cooldownUntil.clear();
  }

  /// Get all active cooldowns (for testing/debugging)
  Map<String, DateTime> get activeCooldowns => Map.unmodifiable(_cooldownUntil);
}
