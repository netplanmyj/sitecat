import 'package:flutter_test/flutter_test.dart';
import 'package:sitecat/utils/validation_utils.dart';

void main() {
  group('ValidationUtils.isValidUrl', () {
    test('accepts valid http/https URLs', () {
      expect(ValidationUtils.isValidUrl('https://example.com'), isTrue);
      expect(ValidationUtils.isValidUrl('http://example.com/path?q=1'), isTrue);
    });

    test('rejects missing scheme or host', () {
      expect(ValidationUtils.isValidUrl('example.com'), isFalse);
      expect(ValidationUtils.isValidUrl('https:///'), isFalse);
      expect(ValidationUtils.isValidUrl(''), isFalse);
    });

    test('trims whitespace before validation', () {
      expect(ValidationUtils.isValidUrl('  https://example.com  '), isTrue);
    });

    test('rejects unsupported schemes', () {
      expect(ValidationUtils.isValidUrl('ftp://example.com'), isFalse);
      expect(ValidationUtils.isValidUrl('file:///tmp/a'), isFalse);
    });
  });
}
