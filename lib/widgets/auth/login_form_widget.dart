import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../common/custom_button.dart';
import '../common/custom_text_field.dart';
import 'country_code_selector.dart';
import '../../models/login_models.dart';

/// Reusable login form widget
class LoginFormWidget extends StatefulWidget {
  final Function(String username, String password) onLogin;
  final bool isLoading;
  final String? error;
  final List<CountryCodeEntity> countries;
  final String? initialPhone;
  final String? initialCountryCode;

  const LoginFormWidget({
    super.key,
    required this.onLogin,
    this.isLoading = false,
    this.error,
    this.countries = const [],
    this.initialPhone,
    this.initialCountryCode,
  });

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _countryCode = LoginValidation.defaultCountryCode;
  bool _isPasswordVisible = false;
  bool _isAgreedToTerms = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
    if (widget.initialCountryCode != null) {
      _countryCode = widget.initialCountryCode!;
    }
  }

  void _onCountryCodeSelected(String code) {
    setState(() {
      _countryCode = code;
    });
  }

  void _onLogin() {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isAgreedToTerms) {
      _showError(ErrorMessages.agreeAuthTips);
      return;
    }

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    // Validate Chinese phone number length
    if (_countryCode == LoginValidation.defaultCountryCode && 
        phone.length != LoginValidation.chinesePhoneLength) {
      _showError(ErrorMessages.phoneError);
      return;
    }

    // Validate password length
    if (password.length < LoginValidation.minPasswordLength || 
        password.length > LoginValidation.maxPasswordLength) {
      _showError(ErrorMessages.pwdLengthError);
      return;
    }

    final username = _countryCode + phone;
    widget.onLogin(username, password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone number input with country code
          Row(
            children: [
              CountryCodeSelector(
                selectedCode: _countryCode,
                countries: widget.countries,
                onCodeSelected: _onCountryCodeSelected,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return ErrorMessages.nameNotNull;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Password input
          CustomTextField(
            controller: _passwordController,
            labelText: 'Password',
            obscureText: !_isPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible 
                  ? Icons.visibility 
                  : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return ErrorMessages.pwdNotNull;
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Terms and conditions checkbox
          Row(
            children: [
              Checkbox(
                value: _isAgreedToTerms,
                onChanged: (value) {
                  setState(() {
                    _isAgreedToTerms = value ?? false;
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAgreedToTerms = !_isAgreedToTerms;
                    });
                  },
                  child: const Text(
                    'I agree to the Terms of Service and Privacy Policy',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Error message
          if (widget.error != null && widget.error!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(UIConstants.borderRadius),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Login button
          CustomButton(
            text: 'Login',
            onPressed: widget.isLoading ? null : _onLogin,
            isLoading: widget.isLoading,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// Registration form widget
class RegistrationFormWidget extends StatefulWidget {
  final Function({
    required String code,
    required String zone,
    required String name,
    required String phone,
    required String password,
    String inviteCode,
  }) onRegister;
  final Function(String zone, String phone) onGetVerificationCode;
  final bool isLoading;
  final bool isGettingCode;
  final String? error;
  final List<CountryCodeEntity> countries;

  const RegistrationFormWidget({
    super.key,
    required this.onRegister,
    required this.onGetVerificationCode,
    this.isLoading = false,
    this.isGettingCode = false,
    this.error,
    this.countries = const [],
  });

  @override
  State<RegistrationFormWidget> createState() => _RegistrationFormWidgetState();
}

class _RegistrationFormWidgetState extends State<RegistrationFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  
  String _countryCode = LoginValidation.defaultCountryCode;
  bool _isPasswordVisible = false;
  bool _isAgreedToTerms = false;
  bool _canGetVerificationCode = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    setState(() {
      _canGetVerificationCode = _phoneController.text.trim().isNotEmpty;
    });
  }

  void _onCountryCodeSelected(String code) {
    setState(() {
      _countryCode = code;
    });
  }

  void _getVerificationCode() {
    final phone = _phoneController.text.trim();
    
    // Validate Chinese phone number length
    if (_countryCode == LoginValidation.defaultCountryCode && 
        phone.length != LoginValidation.chinesePhoneLength) {
      _showError(ErrorMessages.phoneError);
      return;
    }

    widget.onGetVerificationCode(_countryCode, phone);
  }

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isAgreedToTerms) {
      _showError(ErrorMessages.agreeAuthTips);
      return;
    }

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final verificationCode = _verificationCodeController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();

    // Validate Chinese phone number length
    if (_countryCode == LoginValidation.defaultCountryCode && 
        phone.length != LoginValidation.chinesePhoneLength) {
      _showError(ErrorMessages.phoneError);
      return;
    }

    // Validate password length
    if (password.length < LoginValidation.minPasswordLength || 
        password.length > LoginValidation.maxPasswordLength) {
      _showError(ErrorMessages.pwdLengthError);
      return;
    }

    widget.onRegister(
      code: verificationCode,
      zone: _countryCode,
      name: name,
      phone: phone,
      password: password,
      inviteCode: inviteCode,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone number input with country code
          Row(
            children: [
              CountryCodeSelector(
                selectedCode: _countryCode,
                countries: widget.countries,
                onCodeSelected: _onCountryCodeSelected,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return ErrorMessages.nameNotNull;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Verification code input with get code button
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _verificationCodeController,
                  labelText: 'Verification Code',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Verification code is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: CustomButton(
                  text: 'Get Code',
                  onPressed: _canGetVerificationCode && !widget.isGettingCode 
                    ? _getVerificationCode 
                    : null,
                  isLoading: widget.isGettingCode,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Name input
          CustomTextField(
            controller: _nameController,
            labelText: 'Name',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return ErrorMessages.nicknameNotNull;
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Password input
          CustomTextField(
            controller: _passwordController,
            labelText: 'Password',
            obscureText: !_isPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible 
                  ? Icons.visibility 
                  : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return ErrorMessages.pwdNotNull;
              }
              if (value.length < LoginValidation.minPasswordLength ||
                  value.length > LoginValidation.maxPasswordLength) {
                return ErrorMessages.pwdLengthError;
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Invite code input (optional)
          CustomTextField(
            controller: _inviteCodeController,
            labelText: 'Invite Code (Optional)',
          ),
          
          const SizedBox(height: 16),
          
          // Terms and conditions checkbox
          Row(
            children: [
              Checkbox(
                value: _isAgreedToTerms,
                onChanged: (value) {
                  setState(() {
                    _isAgreedToTerms = value ?? false;
                  });
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAgreedToTerms = !_isAgreedToTerms;
                    });
                  },
                  child: const Text(
                    'I agree to the Terms of Service and Privacy Policy',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Error message
          if (widget.error != null && widget.error!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(UIConstants.borderRadius),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Register button
          CustomButton(
            text: 'Register',
            onPressed: widget.isLoading ? null : _onRegister,
            isLoading: widget.isLoading,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _verificationCodeController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }
}
