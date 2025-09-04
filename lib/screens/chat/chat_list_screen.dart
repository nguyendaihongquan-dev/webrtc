import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:wukongimfluttersdk/wkim.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../config/routes.dart';
import '../../widgets/conversation/conversation_item.dart';
import '../../widgets/common/unified_app_bar.dart';
import '../../l10n/app_localizations.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isInitialized = false;
  Timer? _refreshTimer;
  Timer? _initialRefreshTimer;

  @override
  void initState() {
    super.initState();

    print('ChatListScreen: initState called');

    // Initialize WuKongIM when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('ChatListScreen: Calling _initializeWuKongIM');
      _initializeWuKongIM();

      // Set up initial refresh after 1.5 seconds
      _initialRefreshTimer = Timer(const Duration(milliseconds: 3500), () {
        print('ChatListScreen: Initial refresh after 1.5 seconds');
        _refreshConversationsQuietly();
      });

      // Set up periodic refresh every 3 minutes
      _refreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
        print('ChatListScreen: Periodic refresh every 3 minutes');
        _refreshConversationsQuietly();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _initialRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeWuKongIM() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      print('ChatListScreen: Getting ConversationProvider...');
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );
      print('ChatListScreen: Calling conversationProvider.initialize()...');
      await conversationProvider.initialize();
      print('ChatListScreen: ConversationProvider initialization completed');
    } catch (e) {
      print('ChatListScreen: Error initializing WuKongIM: $e');
    }
  }

  // TEMPORARY: Test ContactsProvider

  Future<void> _refreshConversations() async {
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );
    await conversationProvider.refreshConversations();
  }

  /// Refresh conversations quietly without showing loading indicators
  Future<void> _refreshConversationsQuietly() async {
    try {
      final conversationProvider = Provider.of<ConversationProvider>(
        context,
        listen: false,
      );

      // Use the quiet refresh method that doesn't show loading indicators
      await conversationProvider.refreshConversationsQuietly();
    } catch (e) {
      print('ChatListScreen: Error during quiet refresh: $e');
      // Silently handle errors during background refresh
    }
  }

  Widget _buildBody(ConversationProvider conversationProvider) {
    // Show error if any
    if (conversationProvider.error.isNotEmpty) {
      return _buildClayErrorState(conversationProvider.error);
    }

    // Show loading while initializing or syncing conversations
    if (conversationProvider.isLoading ||
        (conversationProvider.isSyncingConversations &&
            conversationProvider.conversations.isEmpty)) {
      return _buildClayLoadingState();
    }

    // Show empty state only when not syncing and no data
    if (conversationProvider.conversations.isEmpty) {
      return _buildClayEmptyState();
    }

    // Show conversations list with animations and slidable behavior
    return SlidableAutoCloseBehavior(
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: conversationProvider.conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversationProvider.conversations[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 450),
              child: SlideAnimation(
                curve: Curves.easeOutQuart,
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  curve: Curves.easeOutQuart,
                  child: ConversationItem(
                    key: ValueKey(
                      '${conversation.msg.channelID}_${conversation.msg.channelType}',
                    ),
                    conversation: conversation,
                    onTap: () async {
                      // Compute unread start orderSeq similar to Android's WKIMUtils.startChat
                      final unreadCount = conversation.msg.unreadCount;
                      int aroundOrderSeq = 0;
                      if (unreadCount > 0) {
                        final channelId = conversation.msg.channelID;
                        final channelType = conversation.msg.channelType;
                        int startSeq;
                        final lastMsgSeq = conversation.msg.lastMsgSeq;
                        if (lastMsgSeq == 0) {
                          // Fallback: query max message seq from SDK DB
                          final maxSeq = await WKIM.shared.messageManager
                              .getMaxMessageSeq(channelId, channelType);
                          startSeq = maxSeq - unreadCount + 1;
                        } else {
                          startSeq = lastMsgSeq - unreadCount + 1;
                        }
                        if (startSeq <= 0) startSeq = 1;
                        // Convert messageSeq to orderSeq using SDK utility
                        aroundOrderSeq = await WKIM.shared.messageManager
                            .getMessageOrderSeq(
                              startSeq,
                              channelId,
                              channelType,
                            );
                      }

                      Navigator.pushNamed(
                        context,
                        AppRoutes.chat,
                        arguments: {
                          'channelId': conversation.msg.channelID,
                          'channelType': conversation.msg.channelType,
                          'aroundOrderSeq': aroundOrderSeq,
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Claymorphism Error State
  Widget _buildClayErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(4, 4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              offset: const Offset(-4, -4),
              blurRadius: 12,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.oops_something_went_wrong,
              style: GoogleFonts.notoSansSc(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.notoSansSc(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeWuKongIM,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }

  // Claymorphism Loading State
  Widget _buildClayLoadingState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(4, 4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              offset: const Offset(-4, -4),
              blurRadius: 12,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connecting to WuKongIM...',
              style: GoogleFonts.notoSansSc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Claymorphism Empty State
  Widget _buildClayEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(4, 4),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              offset: const Offset(-4, -4),
              blurRadius: 12,
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.message_outlined,
                size: 40,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.no_conversations_yet,
              style: GoogleFonts.notoSansSc(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.start_new_conversation,
              style: GoogleFonts.notoSansSc(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.8),
                    offset: const Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationProvider = Provider.of<ConversationProvider>(context);
    Provider.of<LoginProvider>(context);

    return Scaffold(
      appBar: UnifiedAppBar(
        title: 'Messages',
        actions: [
          if (conversationProvider.isRefreshingChannelInfo)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF6B7280).withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: UnifiedBodyContainer(
        child: RefreshIndicator(
          onRefresh: _refreshConversations,
          child: _buildBody(conversationProvider),
        ),
      ),
    );
  }
}
