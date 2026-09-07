import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/kitchen_provider.dart';
import '../../../../core/services/voice_order_security_service.dart';
import '../../../../meal_voice/meal_voice_controller.dart';
import '../../../../meal_voice/meal_voice_settings.dart';

/// Settings screen for MEAL Voice Engine.
///
/// Allows configuring language, speaker, AI provider, and API key.
class MealVoiceSettingsScreen extends StatefulWidget {
  const MealVoiceSettingsScreen({super.key});

  @override
  State<MealVoiceSettingsScreen> createState() => _MealVoiceSettingsScreenState();
}

class _MealVoiceSettingsScreenState extends State<MealVoiceSettingsScreen> {
  late MealVoiceSettings _settings;
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _settings = MealVoiceSettings();
    _settings.load().then((_) {
      _apiKeyController.text = _settings.apiKey;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _settings,
      child: Consumer<MealVoiceSettings>(
        builder: (context, settings, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('MEAL Voice Settings'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Language Selection
                _buildSectionHeader('Voice Language'),
                _buildLanguageDropdown(settings),
                const SizedBox(height: 16),

                // Speaker Selection
                _buildSectionHeader('TTS Voice'),
                _buildSpeakerDropdown(settings),
                const SizedBox(height: 16),

                // AI Provider
                _buildSectionHeader('AI Conversation (Optional)'),
                Text(
                  'Provide your own API key for smarter voice commands',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                _buildAiProviderDropdown(settings),
                const SizedBox(height: 12),

                if (settings.aiProvider != 'none') ...[
                  _buildApiKeyField(settings),
                  const SizedBox(height: 8),
                  Text(
                    _getApiKeyHelp(settings.aiProvider),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  _buildSaveApiKeyButton(settings),
                ],
                const SizedBox(height: 24),

                // Test section
                _buildSectionHeader('Test Voice'),
                _buildTestButton(context),
                const SizedBox(height: 24),

                // Info
                _buildInfoCard(settings),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(MealVoiceSettings settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.language, color: Colors.deepPurple),
        title: const Text('Voice Language'),
        subtitle: Text(settings.languageName),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => _showLanguagePicker(settings),
      ),
    );
  }

  Widget _buildSpeakerDropdown(MealVoiceSettings settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.record_voice_over, color: Colors.deepPurple),
        title: const Text('TTS Speaker'),
        subtitle: Text(settings.speakerName),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => _showSpeakerPicker(settings),
      ),
    );
  }

  Widget _buildAiProviderDropdown(MealVoiceSettings settings) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.smart_toy, color: Colors.deepPurple),
        title: const Text('AI Provider'),
        subtitle: Text(settings.aiProviderName),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: () => _showAiProviderPicker(settings),
      ),
    );
  }

  Widget _buildApiKeyField(MealVoiceSettings settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _apiKeyController,
          obscureText: _obscureKey,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: _getApiKeyHint(settings.aiProvider),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveApiKeyButton(MealVoiceSettings settings) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await settings.setApiKey(_apiKeyController.text);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('API key saved')),
            );
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
        child: const Text('Save API Key', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildTestButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          if (!mounted) return;
          final vc = MealVoiceController();
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          await vc.initialize(
            kitchenProvider: context.read<KitchenProvider>(),
            cartProvider: context.read<CartProvider>(),
            securityService: context.read<VoiceOrderSecurityService>(),
          );
          await vc.startListening();
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Voice test started — say "Hi MEAL"')),
          );
        },
        icon: const Icon(Icons.mic, color: Colors.deepPurple),
        label: const Text('Test Voice', style: TextStyle(color: Colors.deepPurple)),
      ),
    );
  }

  Widget _buildInfoCard(MealVoiceSettings settings) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How it works:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '1. Say "Hi MEAL" to activate\n'
              '2. MEAL greets you and listens\n'
              '3. Say your order naturally\n'
              '4. MEAL confirms and adds to cart',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Language: ${settings.languageName}\n'
              'Speaker: ${settings.speakerName}\n'
              'AI: ${settings.aiProviderName}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getApiKeyHint(String provider) {
    switch (provider) {
      case 'gemini':
        return 'Enter your Gemini API key';
      case 'openai':
        return 'Enter your OpenAI API key';
      default:
        return '';
    }
  }

  String _getApiKeyHelp(String provider) {
    switch (provider) {
      case 'gemini':
        return 'Get your key from aistudio.google.com. Free tier available.';
      case 'openai':
        return 'Get your key from platform.openai.com. Requires billing.';
      default:
        return '';
    }
  }

  void _showLanguagePicker(MealVoiceSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Voice Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: MealVoiceSettings.sarvamLanguages.entries.map((entry) {
                    final isSelected = settings.languageCode == entry.key;
                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check, color: Colors.deepPurple)
                          : const SizedBox(width: 24),
                      title: Text(entry.value),
                      subtitle: Text(entry.key),
                      onTap: () {
                        settings.setLanguage(entry.key);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSpeakerPicker(MealVoiceSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select TTS Voice',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: MealVoiceSettings.sarvamSpeakers.entries.map((entry) {
                    final isSelected = settings.speaker == entry.key;
                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check, color: Colors.deepPurple)
                          : const SizedBox(width: 24),
                      title: Text(entry.value),
                      subtitle: Text(entry.key),
                      onTap: () {
                        settings.setSpeaker(entry.key);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAiProviderPicker(MealVoiceSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select AI Provider',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: MealVoiceSettings.aiProviders.entries.map((entry) {
                    final isSelected = settings.aiProvider == entry.key;
                    return ListTile(
                      leading: isSelected
                          ? const Icon(Icons.check, color: Colors.deepPurple)
                          : const SizedBox(width: 24),
                      title: Text(entry.value),
                      subtitle: Text(entry.key),
                      onTap: () {
                        settings.setAiProvider(entry.key);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
