import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import '../../config/routes.dart';
import '../../l10n/app_localizations.dart';

/// Reusable search button (uses Contacts search implementation)
class AppBarSearchButton extends StatelessWidget {
  const AppBarSearchButton({
    super.key,
    this.iconColor = const Color(0xFF6B7280),
  });

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Ionicons.search_outline, color: iconColor, size: 22),
      onPressed: () {},
    );
  }
}

/// Reusable add (+) popup menu button (uses Messages add implementation)
class AppBarAddMenuButton extends StatelessWidget {
  const AppBarAddMenuButton({
    super.key,
    required this.onNewChat,
    this.iconColor = const Color(0xFF6B7280),
  });

  final VoidCallback onNewChat;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.add, color: iconColor, size: 22),
      onSelected: (value) async {
        switch (value) {
          case 'new_chat':
            onNewChat();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'new_chat',
          child: Text(AppLocalizations.of(context)!.new_chat),
        ),
        // const PopupMenuItem(value: 'scan', child: Text('Scan')), // Scan option temporarily disabled
        const PopupMenuItem(value: 'add_contacts', child: Text('Add Contacts')),
      ],
    );
  }
}

/// Helper to open new chat (group/contact selection) if caller doesn't want to implement
VoidCallback defaultOpenNewChat(BuildContext context) {
  return () {};
}
