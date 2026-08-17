import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../chef/presentation/screens/chef_dashboard.dart';
import '../../../customer/presentation/screens/customer_dashboard.dart';
import '../../../delivery_partner/presentation/screens/delivery_partner_dashboard.dart';
import '../../../admin/presentation/screens/admin_dashboard.dart';
import 'profile_setup_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String role;
  final String? otpCode;
  const OtpScreen({super.key, required this.email, required this.role, this.otpCode});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  String? _otpCode;

  @override
  void initState() {
    super.initState();
    _otpCode = widget.otpCode;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _verifyOtp(String code) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.verifyOtp(
        email: widget.email,
        otp: code,
        onSuccess: (profileExists) {
          if (!mounted) return;
          if (profileExists) {
            final profile = authProvider.userProfile;
            _navigateToDashboard(profile?['role'] as String? ?? widget.role);
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileSetupScreen(email: widget.email, role: widget.role),
              ),
              (route) => false,
            );
          }
        },
        onError: (error) {
          if (mounted) _showError(error);
        },
      );
    } catch (e) {
      if (mounted) _showError('Verification failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateToDashboard(String role) {
    Widget destination;
    switch (role) {
      case 'chef':
        destination = const ChefDashboard();
        break;
      case 'delivery_partner':
        destination = const DeliveryPartnerDashboard();
        break;
      case 'admin':
        destination = const AdminDashboard();
        break;
      default:
        destination = const CustomerDashboard();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _loading) return;
    setState(() => _loading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendOtp(
        email: widget.email,
        onSuccess: (otpCode) {
          if (!mounted) return;
          _otpController.clear();
          _startTimer();
          setState(() => _otpCode = otpCode);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent'), backgroundColor: AppTheme.secondaryColor),
          );
        },
        onError: (error) {
          if (mounted) _showError(error);
        },
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('Verification Code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sent to ${widget.email}', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              if (_otpCode != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('Your OTP', style: TextStyle(fontSize: 14, color: Colors.green.shade700)),
                      const SizedBox(height: 4),
                      Text(
                        _otpCode!,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.green.shade800, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  if (value.length == 6) _verifyOtp(value);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: () => _verifyOtp(_otpController.text.trim()), child: const Text('Verify & Continue')),
              ),
              const SizedBox(height: 20),
              Center(
                child: _secondsRemaining <= 0
                    ? TextButton(onPressed: _resendOtp, child: const Text('Resend OTP', style: TextStyle(color: AppTheme.primaryColor)))
                    : Text('Resend in $_secondsRemaining s', style: TextStyle(color: Colors.grey[500])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
