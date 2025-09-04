import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime time;
  final int? status; // 0: sending, 1: sent, 2: delivered, 3: read
  final String? senderName; // For group chats
  final VoidCallback? onTap;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.time,
    this.status,
    this.senderName,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? theme.primaryColor
                : theme.brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: isMe ? const Radius.circular(0) : null,
              bottomLeft: !isMe ? const Radius.circular(0) : null,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show sender name for group chats
              if (senderName != null && !isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName!,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              
              // Message content
              Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : null,
                  fontSize: 16,
                ),
              ),
              
              const SizedBox(height: 2),
              
              // Time and status
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(time),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  
                  // Show status icon for sent messages
                  if (isMe && status != null) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
  
  Widget _buildStatusIcon() {
    IconData iconData;
    Color iconColor = Colors.white.withOpacity(0.7);
    
    switch (status) {
      case 0: // Sending
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        );
      case 1: // Sent
        iconData = Icons.check;
        break;
      case 2: // Delivered
        iconData = Icons.done_all;
        break;
      case 3: // Read
        iconData = Icons.done_all;
        iconColor = Colors.blue[300]!;
        break;
      default:
        iconData = Icons.error_outline;
        iconColor = Colors.red[300]!;
    }
    
    return Icon(
      iconData,
      size: 16,
      color: iconColor,
    );
  }
}
