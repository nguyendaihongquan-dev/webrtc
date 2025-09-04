/// Class representing all localizable strings for ChatView package.
final class ChatViewLocale {
  const ChatViewLocale({
    required this.today,
    required this.yesterday,
    required this.repliedToYou,
    required this.repliedBy,
    required this.more,
    required this.unsend,
    required this.reply,
    required this.replyTo,
    required this.message,
    required this.reactionPopupTitle,
    required this.photo,
    required this.send,
    required this.you,
    required this.report,
    required this.noMessage,
    required this.somethingWentWrong,
    required this.reload,
  });

  /// Create from Map
  factory ChatViewLocale.fromMap(Map<String, String> map) {
    return ChatViewLocale(
      today: map['today']?.toString() ?? '',
      yesterday: map['yesterday']?.toString() ?? '',
      repliedToYou: map['repliedToYou']?.toString() ?? '',
      repliedBy: map['repliedBy']?.toString() ?? '',
      more: map['more']?.toString() ?? '',
      unsend: map['unsend']?.toString() ?? '',
      reply: map['reply']?.toString() ?? '',
      replyTo: map['replyTo']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      reactionPopupTitle: map['reactionPopupTitle']?.toString() ?? '',
      photo: map['photo']?.toString() ?? '',
      send: map['send']?.toString() ?? '',
      you: map['you']?.toString() ?? '',
      report: map['report']?.toString() ?? '',
      noMessage: map['noMessage']?.toString() ?? '',
      somethingWentWrong: map['somethingWentWrong']?.toString() ?? '',
      reload: map['reload']?.toString() ?? '',
    );
  }

  final String today;
  final String yesterday;
  final String repliedToYou;
  final String repliedBy;
  final String more;
  final String unsend;
  final String reply;
  final String replyTo;
  final String message;
  final String reactionPopupTitle;
  final String photo;
  final String send;
  final String you;
  final String report;
  final String noMessage;
  final String somethingWentWrong;
  final String reload;

  /// English defaults
  static const en = ChatViewLocale(
    today: 'Today',
    yesterday: 'Yesterday',
    repliedToYou: 'Replied to you',
    repliedBy: 'Replied by',
    more: 'More',
    unsend: 'Unsend',
    reply: 'Reply',
    replyTo: 'Replying to',
    message: 'Message',
    reactionPopupTitle: 'Tap and hold to multiply your reaction',
    photo: 'Photo',
    send: 'Send',
    you: 'You',
    report: 'Report',
    noMessage: 'No message',
    somethingWentWrong: 'Something went wrong !!',
    reload: 'Reload',
  );

  /// Chinese (Simplified) defaults
  static const zh = ChatViewLocale(
    today: '今天',
    yesterday: '昨天',
    repliedToYou: '回复了你',
    repliedBy: '回复者',
    more: '更多',
    unsend: '撤回',
    reply: '回复',
    replyTo: '回复给',
    message: '消息',
    reactionPopupTitle: '长按可选择更多表情',
    photo: '照片',
    send: '发送',
    you: '你',
    report: '举报',
    noMessage: '暂无消息',
    somethingWentWrong: '出错了！',
    reload: '重新加载',
  );
}
