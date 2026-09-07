import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/voice_order_security_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class VoicePinDialog extends StatefulWidget {
  final double orderTotal;
  final String orderSummary;
  final Function(String authorizationToken) onAuthorized;
  final VoidCallback? onCancel;
  final VoidCallback? onForgotPin;

  const VoicePinDialog({
    super.key,
    required this.orderTotal,
    required this.orderSummary,
    required this.onAuthorized,
    this.onCancel,
    this.onForgotPin,
  });

  static Future<String?> show({
    required BuildContext context,
    required double orderTotal,
    required String orderSummary,
    VoidCallback? onForgotPin,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VoicePinDialog(
        orderTotal: orderTotal,
        orderSummary: orderSummary,
        onAuthorized: (token) => Navigator.of(context).pop(token),
        onCancel: () => Navigator.of(context).pop(null),
        onForgotPin: onForgotPin,
      ),
    );
  }

  @override
  State<VoicePinDialog> createState() => _VoicePinDialogState();
}

class _VoicePinDialogState extends State<VoicePinDialog> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final int _pinLength = 6;
  bool _isLoading = false;
  String? _error;
  String _enteredPin = '';
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockoutSeconds = 0;

  VoiceOrderSecurityService get _securityService =>
      VoiceOrderSecurityService(api: ApiService(baseUrl: AppConstants.apiBaseUrl));

  bool _serviceInitialized = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _pinLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNodes[0].requestFocus();
      await _initService();
    });
  }

  Future<void> _initService() async {
    final tokenService = TokenService();
    final token = await tokenService.getAccessToken();
    if (token != null) {
      await _securityService.setToken(token);
    }
    _serviceInitialized = true;
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
    setState(() {
      _enteredPin = _controllers.map((c) => c.text).join();
    });
  }

  void _clearPin() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {
      _enteredPin = _controllers.map((c) => c.text).join();
    });
  }

  Future<void> _verify() async {
    if (_enteredPin.length != _pinLength || _isLoading || _isLocked) return;
    if (!_serviceInitialized) {
      setState(() { _error = 'Still connecting...'; });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _securityService.verifyPin(_enteredPin);

    if (!mounted) return;

    if (result.authorized && result.authorizationToken != null) {
      widget.onAuthorized(result.authorizationToken!);
    } else {
      _failedAttempts++;
      final errorMsg = result.error ?? 'Invalid PIN';

      setState(() {
        _isLoading = false;
        _error = errorMsg;
      });

      if (_failedAttempts >= 5) {
        setState(() {
          _isLocked = true;
          _lockoutSeconds = 900;
        });
        _startLockoutTimer();
      }

      _clearPin();
    }
  }

  void _startLockoutTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_lockoutSeconds <= 0) {
        setState(() {
          _isLocked = false;
          _failedAttempts = 0;
        });
        return false;
      }
      setState(() {
        _lockoutSeconds--;
      });
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                   color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Your Order',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.orderSummary,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: \u20B9${widget.orderTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter Voice PIN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildPinInput(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ],
              if (_isLocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Too many attempts. Try again in ${_lockoutSeconds ~/ 60}:${(_lockoutSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading || _isLocked || _enteredPin.length != _pinLength
                      ? null
                      : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: widget.onForgotPin,
                    child: const Text(
                      'Forgot PIN?',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        return Container(
          width: 40,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            obscureText: true,
            obscuringCharacter: '\u2022',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: _controllers[index].text.isNotEmpty
                      ? AppTheme.primaryColor
                      : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) => _onDigit(index, value),
          ),
        );
      }),
    );
  }
}
