import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Friendly stub for sidebar sections that exist in the web client but not in
/// the Flutter app yet.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    this.icon = Icons.hourglass_top_outlined,
    this.message,
  });

  final String title;
  final IconData icon;

  /// Overrides the default "not in the app yet" text (e.g. access denied).
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.emerald500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: AppColors.emerald600),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.fg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  'This section is part of the web client and will reach the\n'
                      'Flutter app soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: context.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
