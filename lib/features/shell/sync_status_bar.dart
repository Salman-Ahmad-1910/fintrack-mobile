import 'package:flutter/material.dart';

import '../../core/local/sync_engine.dart';

/// Thin banner shown under the app header whenever the device is offline or
/// there are queued mutations waiting to reach the server. Driven entirely by
/// [SyncEngine] so every screen reports the same offline/sync state.
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncEngine.online,
      builder: (context, online, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncEngine.pending,
          builder: (context, pending, _) {
            if (online && pending == 0) return const SizedBox.shrink();

            final offline = !online;
            final bg = offline
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFDBEAFE);
            final fg = offline
                ? const Color(0xFF92400E)
                : const Color(0xFF1D4ED8);
            final text = offline
                ? (pending > 0
                      ? 'Offline — $pending change${pending == 1 ? '' : 's'} queued to sync.'
                      : 'Offline — showing cached data.')
                : 'Syncing $pending change${pending == 1 ? '' : 's'}...';

            return Container(
              width: double.infinity,
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    offline ? Icons.cloud_off_outlined : Icons.sync,
                    size: 15,
                    color: fg,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
