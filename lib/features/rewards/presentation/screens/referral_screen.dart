import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/repositories/user_repository_impl.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/reward_provider.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  UserModel? _user;
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userProfile?['uid'] ?? '';
    if (uid.isNotEmpty) {
      final userData = await UserRepositoryImpl().getUser(uid);
      if (mounted) {
        setState(() {
          _user = userData;
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_user != null) {
      Clipboard.setData(ClipboardData(text: _user!.referralCode));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Code copied to clipboard!")),
      );
    }
  }

  void _applyCode() async {
    if (_codeController.text.trim().isEmpty) return;
    if (_user == null) return;

    final provider = context.read<RewardProvider>();
    final userUid = _user!.uid;
    await provider.applyReferralCode(
      code: _codeController.text.trim(),
      userId: userUid,
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Success! HouseCredits added to your wallet."), backgroundColor: AppTheme.secondaryColor),
        );
        _loadUser(); // Refresh balance
        _codeController.clear();
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Refer & Earn")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildIllustration(),
            const SizedBox(height: 32),
            const Text(
              "Share the joy of home-cooked meals!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Invite your friends to Mealin. When they sign up using your code, both of you get ₹50 HouseCredits!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildCodeBox(),
            const SizedBox(height: 48),
            if (_user?.referredBy == null) _buildApplySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      height: 180,
      width: 180,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.card_giftcard, size: 80, color: AppTheme.primaryColor),
    );
  }

  Widget _buildCodeBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("YOUR REFERRAL CODE", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            _user?.referralCode ?? "------",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text("COPY CODE"),
          ),
        ],
      ),
    );
  }

  Widget _buildApplySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Have a referral code?", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  hintText: "Enter code here",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _applyCode,
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 50)),
              child: const Text("Apply"),
            ),
          ],
        ),
      ],
    );
  }
}
