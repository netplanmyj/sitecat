import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/broken_link.dart';
import '../../utils/date_formatter.dart';

class BrokenLinksList extends StatelessWidget {
  final List<BrokenLink> links;

  const BrokenLinksList({super.key, required this.links});

  /// Decode URL-encoded string for better readability
  /// Uses Uri.decodeFull() to preserve URL structure (/, ?, #)
  /// Also attempts to fix double-encoding issues
  String _decodeUrl(String url) {
    try {
      String decoded = Uri.decodeFull(url);

      // Check if the result contains mojibake patterns (Latin-1 misinterpretation)
      // Common patterns: é, ã, ¢, º, etc. in sequences
      // If detected, try to recover the original UTF-8 string
      if (_containsMojibake(decoded)) {
        try {
          // Convert string back to Latin-1 bytes, then decode as UTF-8
          final latin1Bytes = decoded.codeUnits;
          final utf8String = utf8.decode(latin1Bytes, allowMalformed: true);

          // Only use the recovered string if it doesn't contain replacement characters
          if (!utf8String.contains('�')) {
            return utf8String;
          }
        } catch (e) {
          // Recovery failed, use the first decoded result
        }
      }

      return decoded;
    } catch (e) {
      // If decoding fails, return original URL
      return url;
    }
  }

  /// Check if a string contains mojibake (garbled text) patterns
  /// Specifically detects Japanese text that was double-encoded (UTF-8 → Latin-1 → UTF-8)
  bool _containsMojibake(String text) {
    // Japanese UTF-8 bytes when misinterpreted as Latin-1 create specific patterns:
    // Common Japanese chars start with bytes E3-E9, which become é, ã, etc. in Latin-1
    // When re-encoded to UTF-8, these become multi-byte sequences starting with C3
    //
    // Example: 開発 (U+958B U+767A)
    //   UTF-8:     E9 96 8B E7 99 BA
    //   As Latin-1: é  –  ‹  ç  ™  º
    //   Re-encoded: C3 A9 C2 96 C2 8B C3 A7 C2 99 C2 BA
    //
    // Pattern: é (E9→C3A9) followed by –‹ (96 8B→C296 C28B)
    //          ç (E7→C3A7) followed by ™º (99 BA→C299 C2BA)

    // Very specific pattern for double-encoded Japanese:
    // - Multiple C2 bytes (Â) which shouldn't appear in normal European text
    // - é or ç followed by Latin-1 control/extended chars that form Japanese patterns
    final japaneseOnlyPatterns = [
      RegExp(
        r'Â[\x80-\xBF]Â[\x80-\xBF]',
      ), // C2xx C2xx pattern (UTF-8 continuation bytes)
      RegExp(
        r'é[\x80-\x9F][\x80-\x9F]',
      ), // é + two control chars (not in European names)
    ];

    return japaneseOnlyPatterns.any((pattern) => pattern.hasMatch(text));
  }

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
            const SizedBox(height: 16),
            Text(
              'No broken links in this category',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(link.statusCode),
              child: Text(
                link.statusCode.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              _decodeUrl(link.url),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              'Found on: ${_decodeUrl(link.foundOn)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('URL', _decodeUrl(link.url)),
                    const SizedBox(height: 8),
                    _buildDetailRow('Found On', _decodeUrl(link.foundOn)),
                    const SizedBox(height: 8),
                    _buildDetailRow('Status Code', link.statusCode.toString()),
                    if (link.error != null) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Error', link.error!),
                    ],
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Checked At',
                      DateFormatter.formatFullDateTime(link.timestamp),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Type',
                      link.linkType == LinkType.internal
                          ? 'Internal'
                          : 'External',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Color _getStatusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      return Colors.orange;
    } else if (statusCode >= 400 && statusCode < 500) {
      return Colors.red;
    } else if (statusCode >= 500) {
      return Colors.purple;
    }
    return Colors.grey;
  }
}
