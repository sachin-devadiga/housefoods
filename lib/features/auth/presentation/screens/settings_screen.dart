import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/localization/language_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  void _showLanguageDialog(BuildContext context, LanguageProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Language"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("English"),
              leading: Radio<String>(
                value: 'en',
                groupValue: provider.locale.languageCode,
                onChanged: (val) {
                  provider.setLanguage('en');
                  Navigator.pop(context);
                },
              ),
              onTap: () => provider.setLanguage('en'),
            ),
            ListTile(
              title: const Text("हिंदी (Hindi)"),
              leading: Radio<String>(
                value: 'hi',
                groupValue: provider.locale.languageCode,
                onChanged: (val) {
                  provider.setLanguage('hi');
                  Navigator.pop(context);
                },
              ),
              onTap: () => provider.setLanguage('hi'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This action is permanent and will delete all your orders, wallet balance, and profile data.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(context);
              _handleDelete();
            },
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );
  }

  void _handleDelete() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.deleteAccount(
      onSuccess: () {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _buildSectionHeader("Appearance"),
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: themeProvider.themeMode == ThemeMode.dark,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (val) => themeProvider.toggleTheme(val),
            secondary: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: AppTheme.primaryColor),
          ),
          
          const Divider(),
          _buildSectionHeader("Language"),
          ListTile(
            leading: const Icon(Icons.language, color: AppTheme.primaryColor),
            title: const Text("App Language"),
            subtitle: Text(languageProvider.locale.languageCode == 'en' ? "English" : "हिंदी"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, languageProvider),
          ),

          const Divider(),
          _buildSectionHeader("Preferences"),
          SwitchListTile(
            title: const Text("Push Notifications"),
            value: _notificationsEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          
          const Divider(),
          _buildSectionHeader("Legal"),
          _buildSettingsTile(Icons.description_outlined, "Terms of Service", () {}),
          _buildSettingsTile(Icons.privacy_tip_outlined, "Privacy Policy", () {}),
          
          const Divider(),
          _buildSectionHeader("Account"),
          _buildSettingsTile(
            Icons.delete_forever_outlined, 
            "Delete Account", 
            _confirmDeleteAccount,
            textColor: AppTheme.errorColor,
          ),
          
          const SizedBox(height: 40),
          Center(child: Text("Mealin v1.0.0", style: TextStyle(color: Colors.grey[400], fontSize: 12))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.1)),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap, {Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.grey[700]),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
