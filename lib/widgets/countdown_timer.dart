import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown timer widget that updates every second
class CountdownTimer extends StatefulWidget {
  final Duration initialDuration;
  final TextStyle? style;
  final VoidCallback? onComplete;
  final String? prefixText;

  const CountdownTimer({
    super.key,
    required this.initialDuration,
    this.style,
    this.onComplete,
    this.prefixText,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration _remainingTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.initialDuration;
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDuration != widget.initialDuration) {
      _remainingTime = widget.initialDuration;
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        } else {
          timer.cancel();
          // Notify parent that countdown is complete
          widget.onComplete?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;
    final formatted = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final text = widget.prefixText == null
        ? 'Next check available in: $formatted'
        : '${widget.prefixText!}$formatted';

    return Text(
      text,
      style: widget.style ?? const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}
