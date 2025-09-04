import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: color ?? theme.primaryColor, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _buildChild(theme),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _buildChild(theme),
          );
  }

  Widget _buildChild(ThemeData theme) {
    return isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          );
  }
}
