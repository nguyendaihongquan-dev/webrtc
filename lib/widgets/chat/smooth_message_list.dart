import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

class SmoothMessageList extends StatefulWidget {
  final List<WKMsg> messages;
  final ScrollController scrollController;
  final Widget Function(WKMsg message) messageBuilder;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  const SmoothMessageList({
    Key? key,
    required this.messages,
    required this.scrollController,
    required this.messageBuilder,
    this.isLoadingMore = false,
    this.onLoadMore,
  }) : super(key: key);

  @override
  State<SmoothMessageList> createState() => _SmoothMessageListState();
}

class _SmoothMessageListState extends State<SmoothMessageList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<WKMsg> _displayedMessages = [];

  @override
  void initState() {
    super.initState();
    _displayedMessages = List.from(widget.messages);
  }

  @override
  void didUpdateWidget(SmoothMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle new messages with smooth insertion animation
    if (widget.messages.length > _displayedMessages.length) {
      final newMessages = widget.messages
          .take(widget.messages.length - _displayedMessages.length)
          .toList();
      for (int i = 0; i < newMessages.length; i++) {
        _displayedMessages.insert(i, newMessages[i]);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 300),
        );
      }
    } else {
      _displayedMessages = List.from(widget.messages);
    }
  }

  Widget _buildMessageItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    if (widget.isLoadingMore && index == _displayedMessages.length) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (index >= _displayedMessages.length) return const SizedBox.shrink();

    final message = _displayedMessages[index];

    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: FadeTransition(
        opacity: animation.drive(
          Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOut)),
        ),
        child: widget.messageBuilder(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      controller: widget.scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      initialItemCount:
          _displayedMessages.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: _buildMessageItem,
    );
  }
}
