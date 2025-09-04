import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/constants.dart';

/// Verification code input widget with individual digit boxes
class VerificationCodeInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool autoFocus;
  final TextInputType keyboardType;

  const VerificationCodeInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.autoFocus = true,
    this.keyboardType = TextInputType.number,
  });

  @override
  State<VerificationCodeInput> createState() => _VerificationCodeInputState();
}

class _VerificationCodeInputState extends State<VerificationCodeInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  String _code = '';

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (index) => TextEditingController(),
    );
    _focusNodes = List.generate(
      widget.length,
      (index) => FocusNode(),
    );

    // Auto focus on first field
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length > 1) {
      // Handle paste operation
      _handlePaste(value, index);
      return;
    }

    _controllers[index].text = value;

    // Update the complete code
    _updateCode();

    // Move to next field if current field is filled
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Move to previous field if current field is empty and backspace is pressed
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _handlePaste(String pastedText, int startIndex) {
    // Remove non-numeric characters if keyboard type is number
    String cleanText = pastedText;
    if (widget.keyboardType == TextInputType.number) {
      cleanText = pastedText.replaceAll(RegExp(r'[^0-9]'), '');
    }

    // Fill the fields starting from the current index
    for (int i = 0; i < cleanText.length && (startIndex + i) < widget.length; i++) {
      _controllers[startIndex + i].text = cleanText[i];
    }

    // Focus on the next empty field or the last field
    int nextIndex = (startIndex + cleanText.length).clamp(0, widget.length - 1);
    _focusNodes[nextIndex].requestFocus();

    _updateCode();
  }

  void _updateCode() {
    _code = _controllers.map((controller) => controller.text).join();
    
    if (widget.onChanged != null) {
      widget.onChanged!(_code);
    }

    if (_code.length == widget.length) {
      widget.onCompleted(_code);
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
        _updateCode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        widget.length,
        (index) => SizedBox(
          width: 50,
          height: 60,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) => _onKeyEvent(event, index),
            child: TextFormField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: widget.keyboardType,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.borderRadius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.borderRadius),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(0),
              ),
              inputFormatters: widget.keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
              onChanged: (value) => _onChanged(value, index),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple verification code input with single text field
class SimpleVerificationCodeInput extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final String? hintText;
  final bool autoFocus;
  final TextInputType keyboardType;

  const SimpleVerificationCodeInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.hintText,
    this.autoFocus = true,
    this.keyboardType = TextInputType.number,
  });

  @override
  State<SimpleVerificationCodeInput> createState() => _SimpleVerificationCodeInputState();
}

class _SimpleVerificationCodeInputState extends State<SimpleVerificationCodeInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (widget.onChanged != null) {
      widget.onChanged!(value);
    }

    if (value.length == widget.length) {
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      textAlign: TextAlign.center,
      maxLength: widget.length,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText ?? '•' * widget.length,
        hintStyle: TextStyle(
          color: Colors.grey[400],
          letterSpacing: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        counterText: '',
      ),
      inputFormatters: widget.keyboardType == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
      onChanged: _onChanged,
    );
  }
}

/// Verification code input with timer for resend functionality
class VerificationCodeInputWithTimer extends StatefulWidget {
  final int length;
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final VoidCallback? onResendCode;
  final int resendTimerSeconds;
  final String? phoneNumber;

  const VerificationCodeInputWithTimer({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.onResendCode,
    this.resendTimerSeconds = 60,
    this.phoneNumber,
  });

  @override
  State<VerificationCodeInputWithTimer> createState() => 
      _VerificationCodeInputWithTimerState();
}

class _VerificationCodeInputWithTimerState 
    extends State<VerificationCodeInputWithTimer> 
    with TickerProviderStateMixin {
  late AnimationController _timerController;
  bool _canResend = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.resendTimerSeconds;
    _timerController = AnimationController(
      duration: Duration(seconds: widget.resendTimerSeconds),
      vsync: this,
    );
    
    _startTimer();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _canResend = false;
    _remainingSeconds = widget.resendTimerSeconds;
    
    _timerController.reset();
    _timerController.forward();
    
    _timerController.addListener(() {
      setState(() {
        _remainingSeconds = (widget.resendTimerSeconds * 
            (1 - _timerController.value)).round();
      });
    });
    
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _canResend = true;
          _remainingSeconds = 0;
        });
      }
    });
  }

  void _resendCode() {
    if (_canResend && widget.onResendCode != null) {
      widget.onResendCode!();
      _startTimer();
    }
  }

  String _getMaskedPhone(String? phone) {
    if (phone == null || phone.length <= 4) return phone ?? '';
    
    final start = phone.substring(0, 3);
    final end = phone.substring(phone.length - 4);
    final middle = '*' * (phone.length - 7);
    
    return '$start$middle$end';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.phoneNumber != null) ...[
          Text(
            'Enter the verification code sent to',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _getMaskedPhone(widget.phoneNumber),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
        
        VerificationCodeInput(
          length: widget.length,
          onCompleted: widget.onCompleted,
          onChanged: widget.onChanged,
        ),
        
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _canResend 
                ? 'Didn\'t receive the code? ' 
                : 'Resend code in $_remainingSeconds seconds',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (_canResend) ...[
              TextButton(
                onPressed: _resendCode,
                child: const Text('Resend'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
