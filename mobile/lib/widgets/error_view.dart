import 'package:flutter/material.dart';

import '../services/service_exceptions.dart';
import '../theme/app_colors.dart';

/// Shown whenever a service call fails (backend down, timeout, malformed
/// response). The app never crashes on a backend failure — this is the
/// single, reusable "graceful degradation" surface. See spec's Error
/// Handling requirement.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.error, this.onRetry});

  String get _message {
    final e = error;
    if (e is ServiceException) return e.message;
    return 'Something went wrong loading this data.';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.storm, size: 40),
            const SizedBox(height: 12),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
