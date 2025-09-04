import 'message_model.dart';

class Chat {
  final String id;
  final String name;
  String lastMessage;
  DateTime lastMessageTime;
  int unreadCount;
  List<Message> messages;

  Chat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    required this.messages,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      name: json['name'],
      lastMessage: json['lastMessage'],
      lastMessageTime: DateTime.parse(json['lastMessageTime']),
      unreadCount: json['unreadCount'] ?? 0,
      messages:
          (json['messages'] as List?)
              ?.map((m) => Message.fromJson(m))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}
