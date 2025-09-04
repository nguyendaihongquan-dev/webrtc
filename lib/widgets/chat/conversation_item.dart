import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../common/network_avatar.dart';

class ConversationItem extends StatelessWidget {
  final String name;
  final String lastMessage;
  final DateTime time;
  final int unreadCount;
  final VoidCallback onTap;
  final String? avatarUrl;

  const ConversationItem({
    Key? key,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    required this.onTap,
    this.avatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(time.year, time.month, time.day);

    String formattedTime;
    if (messageDate == today) {
      formattedTime = DateFormat('HH:mm').format(time);
    } else if (messageDate == yesterday) {
      formattedTime = 'Yesterday';
    } else {
      formattedTime = DateFormat('dd/MM/yyyy').format(time);
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            NetworkAvatar(
              imageUrl: avatarUrl ?? '',
              displayName: name,
              size: 56,
            ),
            const SizedBox(width: 16),
            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? theme.primaryColor
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
