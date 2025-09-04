import 'package:flutter/material.dart';
import 'message_bubble.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final DateTime time;
  final int status;
  final String? senderName;
  final VoidCallback? onTap;

  const AnimatedMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.time,
    this.status = 1,
    this.senderName,
    this.onTap,
  }) : super(key: key);

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller for fade and scale
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Scale animation for smooth appearance
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    // Slide animation from appropriate side
    _slideAnimation = Tween<Offset>(
      begin: widget.isMe ? const Offset(0.3, 0) : const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    // Start slide animation first
    _slideController.forward();
    
    // Start fade and scale animations with slight delay for smooth effect
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: MessageBubble(
            message: widget.message,
            isMe: widget.isMe,
            time: widget.time,
            status: widget.status,
            senderName: widget.senderName,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}