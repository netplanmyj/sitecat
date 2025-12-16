import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sitecat/services/link_checker/http_client.dart';

class _FakeHttpClient extends http.BaseClient {
  int headCalls = 0;
  int getCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'HEAD') {
      headCalls++;
      // First HEAD call fails (simulate transient), second succeeds (200)
      if (headCalls == 1) {
        // Simulate a network error by throwing
        throw http.ClientException('Transient network error');
      }
      return http.StreamedResponse(
        Stream.value([]),
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }

    if (request.method == 'GET') {
      getCalls++;
      // First GET returns 500, second returns 200 (retry path)
      if (getCalls == 1) {
        return http.StreamedResponse(Stream.value([]), 500);
      }
      final body = '<html><body><a href="/x">x</a></body></html>';
      return http.StreamedResponse(
        Stream.value(body.codeUnits),
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    }

    return http.StreamedResponse(Stream.value([]), 200);
  }
}

void main() {
  group('LinkCheckerHttpClient retry behavior', () {
    test('checkUrlHead retries once on transient network error', () async {
      final fake = _FakeHttpClient();
      final client = LinkCheckerHttpClient(fake);

      final res = await client.checkUrlHead('https://example.com');
      expect(res.statusCode, 200);
      expect(fake.headCalls, 2); // failed once, then succeeded
    });

    test('fetchHtmlContent retries GET after 5xx and returns body', () async {
      final fake = _FakeHttpClient();
      final client = LinkCheckerHttpClient(fake);

      final html = await client.fetchHtmlContent('https://example.com');
      expect(html, contains('<html'));
      expect(fake.getCalls, 2); // first 500, second 200
    });
  });
}
