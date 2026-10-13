import 'package:flutter/material.dart';

import 'message_filtered_list.dart';

/// Flutter counterpart of `client/src/app/(app)/messages/expired/page.tsx`.
class ExpiredMessagesScreen extends StatelessWidget {
  const ExpiredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MessageFilteredListScreen(isExpiry: true);
}
