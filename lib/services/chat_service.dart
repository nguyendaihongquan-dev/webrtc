import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  static const String _chatsKey = 'chats';

  // Get all chats from storage
  Future<List<Chat>> getChats() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? chatsJson = prefs.getString(_chatsKey);

    if (chatsJson == null) return [];

    try {
      final List<dynamic> chatsData = jsonDecode(chatsJson);
      return chatsData.map((chat) => Chat.fromJson(chat)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save chats to storage
  Future<void> saveChats(List<Chat> chats) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> chatsData = chats
        .map((chat) => chat.toJson())
        .toList();
    await prefs.setString(_chatsKey, jsonEncode(chatsData));
  }

  // Get a specific chat
  Future<Chat?> getChat(String chatId) async {
    final chats = await getChats();
    try {
      return chats.firstWhere((chat) => chat.id == chatId);
    } catch (e) {
      return null;
    }
  }

  // Send a message - in real app, this would make an API call
  Future<bool> sendMessage(String chatId, Message message) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final chats = await getChats();
      final index = chats.indexWhere((chat) => chat.id == chatId);

      if (index != -1) {
        chats[index].messages.add(message);
        chats[index].lastMessage = message.content;
        chats[index].lastMessageTime = message.timestamp;

        await saveChats(chats);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Create a new chat - in real app, this would make an API call
  Future<Chat?> createChat(
    String name,
    String initialMessage,
    String userId,
  ) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    try {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: userId,
        content: initialMessage,
        timestamp: DateTime.now(),
        isRead: true,
      );

      final chat = Chat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        lastMessage: initialMessage,
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        messages: [message],
      );

      final chats = await getChats();
      chats.add(chat);
      await saveChats(chats);

      return chat;
    } catch (e) {
      return null;
    }
  }
}
