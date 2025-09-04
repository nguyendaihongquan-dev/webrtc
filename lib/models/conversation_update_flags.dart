/// Model to track which parts of a conversation need UI updates
///
/// This mirrors the Android implementation's selective update system
/// using boolean flags to control what gets refreshed in the UI
class ConversationUpdateFlags {
  /// Whether channel info (name, avatar) should be refreshed
  bool isRefreshChannelInfo = false;

  /// Whether unread count should be updated
  bool isResetCounter = false;

  /// Whether reminder/mention indicators should be updated
  bool isResetReminders = false;

  /// Whether message content preview should be updated
  bool isResetContent = false;

  /// Whether timestamp should be updated
  bool isResetTime = false;

  /// Whether typing indicator should be updated
  bool isResetTyping = false;

  /// Whether message status (sent/delivered/read) should be updated
  bool isRefreshStatus = false;

  /// Whether the entire conversation item should be rebuilt (e.g., when moved to top)
  bool isFullRefresh = false;

  /// Username currently typing (for group chats)
  String typingUserName = '';

  /// Timestamp when typing started (for auto-clearing)
  int typingStartTime = 0;

  ConversationUpdateFlags();

  /// Create flags for a new message update
  ConversationUpdateFlags.newMessage() {
    isResetContent = true;
    isResetTime = true;
    isResetCounter = true;
    isFullRefresh =
        true; // Force full refresh when new message moves conversation to top
  }

  /// Create flags for unread count only update
  ConversationUpdateFlags.unreadCountOnly() {
    isResetCounter = true;
  }

  /// Create flags for typing indicator update
  ConversationUpdateFlags.typing({
    required String userName,
    required int startTime,
  }) {
    isResetTyping = true;
    typingUserName = userName;
    typingStartTime = startTime;
  }

  /// Check if typing indicator has expired (8 seconds timeout like Android)
  bool get isTypingExpired {
    if (!isResetTyping || typingStartTime == 0) return true;
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (currentTime - typingStartTime) > 8;
  }

  /// Create flags for channel info update
  ConversationUpdateFlags.channelInfo() {
    isRefreshChannelInfo = true;
  }

  /// Create flags for message status update
  ConversationUpdateFlags.messageStatus() {
    isRefreshStatus = true;
  }

  /// Check if any update flag is set
  bool get hasUpdates =>
      isRefreshChannelInfo ||
      isResetCounter ||
      isResetReminders ||
      isResetContent ||
      isResetTime ||
      isResetTyping ||
      isRefreshStatus ||
      isFullRefresh;

  /// Reset all flags after processing updates
  void resetFlags() {
    isRefreshChannelInfo = false;
    isResetCounter = false;
    isResetReminders = false;
    isResetContent = false;
    isResetTime = false;
    isResetTyping = false;
    isRefreshStatus = false;
    isFullRefresh = false;
    typingUserName = '';
    typingStartTime = 0;
  }

  @override
  String toString() {
    final flagsList = <String>[];
    if (isRefreshChannelInfo) flagsList.add('channelInfo');
    if (isResetCounter) flagsList.add('counter');
    if (isResetReminders) flagsList.add('reminders');
    if (isResetContent) flagsList.add('content');
    if (isResetTime) flagsList.add('time');
    if (isResetTyping) flagsList.add('typing:$typingUserName');
    if (isRefreshStatus) flagsList.add('status');
    if (isFullRefresh) flagsList.add('fullRefresh');

    return 'ConversationUpdateFlags{${flagsList.join(', ')}}';
  }
}
