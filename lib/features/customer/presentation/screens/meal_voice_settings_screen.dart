import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _settings = MealVoiceSettings();
    _settings.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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

                // AI Status
                _buildSectionHeader('AI Conversation'),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.smart_toy,
                      color: Colors.green,
                    ),
                    title: const Text('Gemini AI'),
                    subtitle: const Text('Powered by backend — always available'),
                  ),
                ),
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
              'AI: Gemini (server-side)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
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
}
