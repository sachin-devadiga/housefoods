import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'meal_voice_controller.dart';
import 'meal_voice_state.dart';

/// Developer test screen for MEAL Voice Engine.
/// Shows full workflow state, transcript, parsed command, and TTS response.
class MealVoiceTestScreen extends StatefulWidget {
  const MealVoiceTestScreen({super.key});

  @override
  State<MealVoiceTestScreen> createState() => _MealVoiceTestScreenState();
}

class _MealVoiceTestScreenState extends State<MealVoiceTestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealVoiceController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        title: const Text('MEAL Voice Test', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MealVoiceController>().initialize(),
          ),
        ],
      ),
      body: Consumer<MealVoiceController>(
        builder: (context, controller, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(controller),
                const SizedBox(height: 16),
                _buildStateCard(controller),
                _buildTranscriptCard(controller),
                _buildParsedCommandCard(controller),
                _buildTtsResponseCard(controller),
                _buildSearchResultCard(controller),
                _buildConfirmationCard(controller),
                const SizedBox(height: 12),
                _buildActionButtons(controller),
                const SizedBox(height: 12),
                _buildSystemStatus(controller),
                const SizedBox(height: 12),
                _buildDebugLog(controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(MealVoiceController controller) {
    final isListening = controller.state == MealVoiceState.listeningForWakeWord;
    final isCommandListening = controller.state == MealVoiceState.listeningToUser;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCommandListening
              ? [Colors.orange, Colors.deepOrange]
              : isListening
                  ? [Colors.green, Colors.teal]
                  : [Colors.deepPurple, Colors.purple],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            isCommandListening ? Icons.mic : Icons.mic_none,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          const Text(
            'MEAL',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            _getStateLabel(controller.state),
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard(MealVoiceController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current State', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              controller.state.name.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getStateColor(controller.state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptCard(MealVoiceController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last Transcript', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              controller.lastTranscript.isEmpty ? '(none)' : controller.lastTranscript,
              style: TextStyle(
                fontSize: 16,
                color: controller.lastTranscript.isEmpty ? Colors.grey : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedCommandCard(MealVoiceController controller) {
    final cmd = controller.lastCommand;
    if (cmd == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parsed Command', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            _commandRow('Intent', cmd.intent.name.toUpperCase()),
            _commandRow('Items', '${cmd.items.length}'),
            for (final item in cmd.items)
              _commandRow('  Item', '${item.quantity}x ${item.itemName}'),
            if (cmd.hasRestaurant) _commandRow('Restaurant', cmd.restaurant!),
            if (cmd.hasBakery) _commandRow('Bakery', cmd.bakery!),
          ],
        ),
      ),
    );
  }

  Widget _commandRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildTtsResponseCard(MealVoiceController controller) {
    if (controller.ttsResponse.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TTS Response', style: TextStyle(fontSize: 12, color: Colors.blue)),
            const SizedBox(height: 4),
            Text(controller.ttsResponse, style: const TextStyle(fontSize: 14, color: Colors.blue)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(MealVoiceController controller) {
    if (controller.searchResults.isEmpty && controller.notFoundItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.searchResults.isNotEmpty) ...[
              Text(
                'Found ${controller.searchResults.length} item${controller.searchResults.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
              const SizedBox(height: 4),
              for (final result in controller.searchResults)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _commandRow(result.menuItem.name, '₹${result.menuItem.price} × ${result.kitchen.name}'),
                ),
            ],
            if (controller.notFoundItems.isNotEmpty) ...[
              if (controller.searchResults.isNotEmpty) const SizedBox(height: 8),
              Text(
                'Not found: ${controller.notFoundItems.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard(MealVoiceController controller) {
    if (!controller.awaitingConfirmation) return const SizedBox.shrink();

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.help_outline, size: 32, color: Colors.orange),
            const SizedBox(height: 8),
            const Text(
              'Awaiting Confirmation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 4),
            const Text(
              'Say "Yes" or "No"',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(MealVoiceController controller) {
    final isRunning = controller.state == MealVoiceState.listeningForWakeWord ||
        controller.state == MealVoiceState.listeningToUser;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isRunning ? null : () => controller.startListening(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('START MEAL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isRunning ? () => controller.stopListening() : null,
            icon: const Icon(Icons.stop),
            label: const Text('STOP MEAL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatus(MealVoiceController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            _statusRow('Wake Word', true),
            _statusRow('Speech Recognition', controller.microphoneAvailable),
            _statusRow('TTS', controller.ttsAvailable),
            _statusRow('Cart Integration', controller.lastCommand != null || controller.state != MealVoiceState.idle),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, bool working) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            working ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: working ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDebugLog(MealVoiceController controller) {
    return Card(
      color: const Color(0xFF1a1a2e),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Debug Log', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: controller.logs.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final log = controller.logs[controller.logs.length - 1 - index];
                  return Text(
                    log,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF00ff41),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStateLabel(MealVoiceState state) {
    switch (state) {
      case MealVoiceState.idle:
        return 'Not started';
      case MealVoiceState.initializing:
        return 'Initializing...';
      case MealVoiceState.listeningForWakeWord:
        return 'Say "Hi MEAL"';
      case MealVoiceState.wakeDetected:
        return 'Wake word detected!';
      case MealVoiceState.listeningToUser:
        return 'Listening for command...';
      case MealVoiceState.processingSpeech:
        return 'Processing speech...';
      case MealVoiceState.parsingCommand:
        return 'Understanding command...';
      case MealVoiceState.searchingMenu:
        return 'Searching restaurants...';
      case MealVoiceState.confirmationRequired:
        return 'Confirm? Say "Yes" or "No"';
      case MealVoiceState.addingToCart:
        return 'Adding to cart...';
      case MealVoiceState.commandSuccess:
        return 'Done! Return to listening...';
      case MealVoiceState.commandUnknown:
        return 'Command not understood';
      case MealVoiceState.commandError:
        return 'Error occurred';
      case MealVoiceState.userDenied:
        return 'Cancelled';
      case MealVoiceState.stopped:
        return 'Stopped';
      case MealVoiceState.error:
        return 'Error';
    }
  }

  Color _getStateColor(MealVoiceState state) {
    switch (state) {
      case MealVoiceState.listeningForWakeWord:
      case MealVoiceState.listeningToUser:
        return Colors.green;
      case MealVoiceState.wakeDetected:
      case MealVoiceState.commandSuccess:
        return Colors.blue;
      case MealVoiceState.confirmationRequired:
        return Colors.orange;
      case MealVoiceState.error:
      case MealVoiceState.commandError:
        return Colors.red;
      case MealVoiceState.stopped:
      case MealVoiceState.userDenied:
        return Colors.grey;
      default:
        return Colors.deepPurple;
    }
  }
}
