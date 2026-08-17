import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'customer';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();

      authProvider.sendOtp(
        email: email,
        onSuccess: (otpCode) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(email: email, role: _selectedRole, otpCode: otpCode),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Welcome to Mealin",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter your email to receive an OTP",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    hintText: "you@example.com",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Required";
                    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!regex.hasMatch(value.trim())) return "Enter a valid email";
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                const Text("I want to:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _buildRoleCard(
                  title: "Order Food",
                  subtitle: "Looking for fresh home-cooked meals",
                  role: 'customer',
                  icon: Icons.fastfood,
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  title: "Start a Kitchen",
                  subtitle: "Share my cooking with others",
                  role: 'chef',
                  icon: Icons.restaurant,
                ),
                const SizedBox(height: 16),
                _buildRoleCard(
                  title: "Deliver Food",
                  subtitle: "Earn money delivering meals",
                  role: 'delivery_partner',
                  icon: Icons.delivery_dining,
                ),
                const SizedBox(height: 32),
                authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _onSendOtp,
                          child: const Text("Send Email OTP"),
                        ),
                      ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    "By continuing, you agree to our Terms & Conditions",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({required String title, required String subtitle, required String role, required IconData icon}) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: 2,
          ),
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
