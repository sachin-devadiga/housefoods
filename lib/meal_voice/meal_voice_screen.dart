import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'meal_voice_controller.dart';
import 'meal_voice_state.dart';
import 'meal_voice_service.dart';

/// Developer test screen for MEAL Voice Engine.
/// Temporary screen for testing wake-word detection.
class MealVoiceTestScreen extends StatefulWidget {
  const MealVoiceTestScreen({super.key});

  @override
  State<MealVoiceTestScreen> createState() => _MealVoiceTestScreenState();
}

class _MealVoiceTestScreenState extends State<MealVoiceTestScreen> {
  StreamSubscription<MealVoiceEvent>? _eventSub;
  final List<String> _logs = [];
  Map<String, dynamic> _nativeStatus = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initController();
    });
  }

  Future<void> _initController() async {
    final controller = context.read<MealVoiceController>();
    await controller.initialize();

    // Subscribe to events for log display
    _eventSub = MealVoiceService.instance.events.listen((event) {
      if (event is EngineLog) {
        setState(() => _logs.add('[${event.level.toUpperCase()}] ${event.message}'));
      }
    });

    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await MealVoiceService.instance.getStatus();
    setState(() => _nativeStatus = status);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MEAL Voice Test'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: Consumer<MealVoiceController>(
        builder: (context, controller, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // MEAL Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple, Colors.purple.shade300],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.mic,
                          size: 64,
                          color: controller.isListening ? Colors.greenAccent : Colors.white,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MEAL',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                        const Text(
                          'Voice Engine',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Section
                _buildSectionTitle('Status'),
                _buildStatusCard('Wake Word Status', _getStateLabel(controller.state)),
                _buildStatusCard('Microphone', controller.microphoneAvailable ? 'Available' : 'Unavailable'),
                _buildStatusCard('Permission', controller.permissionGranted ? 'Granted' : 'Denied'),
                _buildStatusCard('Service', controller.isListening ? 'Running' : 'Stopped'),
                _buildStatusCard('Last Event', controller.lastEvent),
                if (controller.errorMessage != null)
                  _buildStatusCard('Error', controller.errorMessage!, isError: true),

                // Detection Result
                if (controller.state == MealVoiceState.wakeDetected)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            Text(
                              'HI MEAL DETECTED',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            if (controller.lastWakeDetected != null)
                              Text(
                                controller.lastWakeDetected!.toIso8601String().substring(11, 19),
                                style: TextStyle(color: Colors.green.shade600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: controller.isListening ? null : () => _startListening(controller),
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text('START MEAL', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(0, 50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: controller.isListening ? () => _stopListening(controller) : null,
                        icon: const Icon(Icons.stop, color: Colors.white),
                        label: const Text('STOP MEAL', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(0, 50),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _testMicrophone(controller),
                        icon: const Icon(Icons.mic),
                        label: const Text('TEST MICROPHONE'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 45)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _requestPermission(controller),
                        icon: const Icon(Icons.security),
                        label: const Text('REQUEST PERMISSION'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 45)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Debug Log
                _buildSectionTitle('Debug Log'),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _logs.isEmpty
                      ? const Text('No logs yet', style: TextStyle(color: Colors.white38))
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (ctx, i) => Text(
                            _logs[i],
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                // Native Status
                _buildSectionTitle('Native Service Status'),
                ..._nativeStatus.entries.map((e) => _buildStatusCard(e.key, '${e.value}')),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStateLabel(MealVoiceState state) {
    switch (state) {
      case MealVoiceState.idle: return 'Idle';
      case MealVoiceState.initializing: return 'Initializing...';
      case MealVoiceState.listeningForWakeWord: return 'Listening for "Hi MEAL"';
      case MealVoiceState.wakeDetected: return 'WAKE DETECTED!';
      case MealVoiceState.listeningToUser: return 'Listening to user...';
      case MealVoiceState.processing: return 'Processing...';
      case MealVoiceState.speaking: return 'Speaking...';
      case MealVoiceState.error: return 'Error';
      case MealVoiceState.stopped: return 'Stopped';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusCard(String label, String value, {bool isError = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isError ? Colors.red : null,
          ),
        ),
      ),
    );
  }

  Future<void> _startListening(MealVoiceController controller) async {
    if (!controller.permissionGranted) {
      await _requestPermission(controller);
      if (!controller.permissionGranted) return;
    }
    await controller.startListening();
    _refreshStatus();
  }

  Future<void> _stopListening(MealVoiceController controller) async {
    await controller.stopListening();
    _refreshStatus();
  }

  Future<void> _testMicrophone(MealVoiceController controller) async {
    if (!controller.permissionGranted) {
      await _requestPermission(controller);
    }
    final available = await MealVoiceService.instance.isMicrophoneAvailable();
    setState(() => _logs.add('[INFO] Microphone available: $available'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(available ? 'Microphone available' : 'Microphone unavailable')),
      );
    }
  }

  Future<void> _requestPermission(MealVoiceController controller) async {
    await controller.requestPermission();
    setState(() => _logs.add('[INFO] Permission: ${controller.permissionGranted ? "granted" : "denied"}'));
  }
}
