import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/link_checker_provider.dart';
import '../../models/site.dart';
import '../countdown_timer.dart';

/// Widget for link check button and options
class LinkCheckButton extends StatefulWidget {
  final Site site;
  final bool showContinueScan;
  final VoidCallback onCheckComplete;
  final void Function(String error) onCheckError;

  const LinkCheckButton({
    super.key,
    required this.site,
    required this.showContinueScan,
    required this.onCheckComplete,
    required this.onCheckError,
  });

  @override
  State<LinkCheckButton> createState() => _LinkCheckButtonState();
}

class _LinkCheckButtonState extends State<LinkCheckButton> {
  bool _checkExternalLinks = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LinkCheckerProvider>(
      builder: (context, linkChecker, _) {
        final state = linkChecker.getCheckState(widget.site.id);
        final timeUntilNext = linkChecker.getTimeUntilNextCheck(widget.site.id);
        final canCheck = linkChecker.canCheckSite(widget.site.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // External links checkbox
            CheckboxListTile(
              value: _checkExternalLinks,
              onChanged: state == LinkCheckState.checking
                  ? null
                  : (value) {
                      setState(() {
                        _checkExternalLinks = value ?? false;
                      });
                    },
              title: const Text('Check external links'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Check/Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state == LinkCheckState.checking || !canCheck
                    ? null
                    : () => widget.showContinueScan
                          ? _continueScan(context)
                          : _checkLinks(context),
                icon: state == LinkCheckState.checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        widget.showContinueScan
                            ? Icons.play_arrow
                            : Icons.search,
                      ),
                label: Text(
                  state == LinkCheckState.checking
                      ? 'Checking...'
                      : widget.showContinueScan
                      ? 'Continue Scan'
                      : 'Check Links',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: widget.showContinueScan
                      ? Colors.green
                      : Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // Cooldown timer (applies to start/continue)
            if (timeUntilNext != null) ...[
              const SizedBox(height: 8),
              CountdownTimer(
                initialDuration: timeUntilNext,
                onComplete: () {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _checkLinks(BuildContext context) async {
    final linkChecker = context.read<LinkCheckerProvider>();

    try {
      await linkChecker.checkSiteLinks(
        widget.site,
        checkExternalLinks: _checkExternalLinks,
      );
      widget.onCheckComplete();
    } catch (e) {
      widget.onCheckError(e.toString());
    }
  }

  Future<void> _continueScan(BuildContext context) async {
    final linkChecker = context.read<LinkCheckerProvider>();

    try {
      await linkChecker.checkSiteLinks(
        widget.site,
        checkExternalLinks: _checkExternalLinks,
        continueFromLastScan: true,
      );
      widget.onCheckComplete();
    } catch (e) {
      widget.onCheckError(e.toString());
    }
  }
}
