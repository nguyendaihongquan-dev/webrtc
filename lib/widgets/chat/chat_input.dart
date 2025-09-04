import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final bool enabled;

  const ChatInput({
    Key? key, 
    required this.onSend,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _textController = TextEditingController();
  bool _isComposing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || !widget.enabled) return;

    widget.onSend(text.trim());
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () {
                // Handle attachment
              },
            ),
            // Text field
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: widget.enabled,
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.trim().isNotEmpty;
                  });
                },
                onSubmitted: (_isComposing && widget.enabled) ? _handleSubmitted : null,
                decoration: InputDecoration(
                  hintText: widget.enabled ? 'Type a message' : 'Sending...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Container(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  color: _isComposing
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                onPressed: (_isComposing && widget.enabled)
                    ? () => _handleSubmitted(_textController.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
