import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/token_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/delivery_partner_provider.dart';

class DeliveryOtpScreen extends StatefulWidget {
  final dynamic deliveryId;
  final String customerName;

  const DeliveryOtpScreen({super.key, required this.deliveryId, required this.customerName});

  @override
  State<DeliveryOtpScreen> createState() => _DeliveryOtpScreenState();
}

class _DeliveryOtpScreenState extends State<DeliveryOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;

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

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index) {
    if (_controllers[index].text.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tokenService = TokenService();
      final token = await tokenService.getAccessToken();
      final api = ApiService(baseUrl: AppConstants.apiBaseUrl);
      if (token != null) api.setToken(token);

      await api.post(
        '${AppConstants.verifyDeliveryOtpEndpoint}/${widget.deliveryId}/verify-otp/',
        body: {'otp': otp},
      );

      if (mounted) {
        context.read<DeliveryPartnerProvider>().fetchMyDeliveries();
        context.read<DeliveryPartnerProvider>().fetchAvailableOrders();
        context.read<DeliveryPartnerProvider>().fetchEarnings();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery confirmed!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().contains('Invalid OTP') ? 'Invalid OTP. Please try again.' : 'Verification failed. Please try again.';
        });
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Delivery OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.lock_outline, size: 64, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Enter OTP from ${widget.customerName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the customer for their 6-digit delivery OTP',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 48,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (_) => _onDigitChanged(index),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _otp.length == 6 ? _verifyOtp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Verify & Complete Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
