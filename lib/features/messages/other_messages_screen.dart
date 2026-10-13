import 'package:flutter/material.dart';

import 'message_filtered_list.dart';

/// Flutter counterpart of `client/src/app/(app)/messages/other/page.tsx`.
class OtherMessagesScreen extends StatelessWidget {
  const OtherMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MessageFilteredListScreen(isExpiry: false);
}
