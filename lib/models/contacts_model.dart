import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';

/// UI entity for displaying contacts, matching Android FriendUIEntity.java
class ContactUIEntity {
  final WKChannel channel;
  String pying; // Pinyin for sorting
  bool check;
  bool isCanCheck;
  bool isSpecial; // For special contacts like "New Friends", "Group Chats"
  String? specialType; // Type identifier for special contacts
  int? badgeCount; // For notification badges

  ContactUIEntity({
    required this.channel,
    this.pying = '',
    this.check = false,
    this.isCanCheck = true,
    this.isSpecial = false,
    this.specialType,
    this.badgeCount,
  });

  /// Get display name (remark if available, otherwise channel name)
  String get displayName {
    // Special display names for system channels
    if (channel.channelID == "u_10000") {
      return "System Notice";
    }
    if (channel.channelID == "fileHelper") {
      return "File Transfer";
    }

    // Normal display logic
    if (channel.channelRemark.isNotEmpty) {
      return channel.channelRemark;
    }
    return channel.channelName;
  }

  /// Create special contact (New Friends, Group Chats, etc.)
  factory ContactUIEntity.special({
    required String channelId,
    required String name,
    required String specialType,
    int? badgeCount,
  }) {
    final channel = WKChannel(channelId, 0); // 0 for special type
    channel.channelName = name;

    return ContactUIEntity(
      channel: channel,
      pying: name.substring(0, 1).toUpperCase(),
      isSpecial: true,
      specialType: specialType,
      badgeCount: badgeCount,
      isCanCheck: false,
    );
  }
}

/// Special contact types matching Android implementation
class SpecialContactType {
  static const String newFriends = 'new_friends';
  static const String groupChats = 'group_chats';
  static const String fileTransfer = 'file_transfer';
  static const String systemNotice = 'system_notice';
}

/// Contact menu item for header section
class ContactMenuItem {
  final String id;
  final String title;
  final String iconPath;
  final int badgeCount;
  final VoidCallback? onTap;

  ContactMenuItem({
    required this.id,
    required this.title,
    required this.iconPath,
    this.badgeCount = 0,
    this.onTap,
  });
}

/// Contacts section for organizing different types of contacts
class ContactsSection {
  final String title;
  final List<ContactUIEntity> contacts;
  final bool showIndex; // Whether to show alphabetical index

  ContactsSection({
    required this.title,
    required this.contacts,
    this.showIndex = false,
  });
}
