import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/voice_order_security_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class VoicePinSetupScreen extends StatefulWidget {
  final bool isReset;
  final VoidCallback? onComplete;

  const VoicePinSetupScreen({
    super.key,
    this.isReset = false,
    this.onComplete,
  });

  @override
  State<VoicePinSetupScreen> createState() => _VoicePinSetupScreenState();
}

class _VoicePinSetupScreenState extends State<VoicePinSetupScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final int _pinLength = 6;
  bool _isLoading = false;
  String? _error;
  String _enteredPin = '';
  bool _isConfirmStep = false;
  String _firstPin = '';
  bool _isSuccess = false;

  VoiceOrderSecurityService _securityService = VoiceOrderSecurityService(
    api: ApiService(baseUrl: ''),
  );

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _pinLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    _initService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  Future<void> _initService() async {
    final tokenService = TokenService();
    final token = await tokenService.getAccessToken();
    _securityService = VoiceOrderSecurityService(
      api: ApiService(baseUrl: AppConstants.apiBaseUrl),
    );
    await _securityService.setToken(token);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigit(int index, String value) {
    if (value.isNotEmpty && index < _pinLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _updatePin();
  }

  void _updatePin() {
    setState(() {
      _enteredPin = _controllers.map((c) => c.text).join();
    });
  }

  void _clearPin() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    _updatePin();
  }

  Future<void> _submit() async {
    if (_enteredPin.length != _pinLength) return;

    if (!_isConfirmStep) {
      setState(() {
        _firstPin = _enteredPin;
        _isConfirmStep = true;
        _error = null;
      });
      _clearPin();
      return;
    }

    if (_enteredPin != _firstPin) {
      setState(() {
        _error = 'PINs do not match. Please try again.';
        _isConfirmStep = false;
        _firstPin = '';
      });
      _clearPin();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.isReset) {
        await _securityService.resetPin(_enteredPin);
      } else {
        await _securityService.setupPin(_enteredPin);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          widget.onComplete?.call();
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to set PIN. Please try again.';
        });
        _clearPin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSuccess ? Icons.check_circle : Icons.lock_outline,
                        size: 40,
                        color: _isSuccess ? Colors.green : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isSuccess
                          ? 'PIN Set Successfully!'
                          : _isConfirmStep
                              ? 'Confirm Your PIN'
                              : widget.isReset
                                  ? 'Reset Voice PIN'
                                  : 'Set Voice PIN',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isSuccess
                          ? 'Your Voice PIN is ready'
                          : _isConfirmStep
                              ? 'Re-enter your PIN to confirm'
                              : 'This PIN protects your voice orders.\nYou\'ll need it before MEAL places an order.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildPinInput(),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red[700], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading || _isSuccess || _enteredPin.length != _pinLength
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isConfirmStep ? 'Confirm PIN' : 'Next',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinInput() {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pinLength, (index) {
          return Container(
            width: 44,
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              obscureText: true,
              obscuringCharacter: '\u2022',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _controllers[index].text.isNotEmpty
                        ? AppTheme.primaryColor
                        : Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: _controllers[index].text.isNotEmpty
                    ? AppTheme.primaryColor.withOpacity(0.04)
                    : Colors.grey[50],
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) => _onDigit(index, value),
            ),
          );
        }),
      ),
    );
  }
}
