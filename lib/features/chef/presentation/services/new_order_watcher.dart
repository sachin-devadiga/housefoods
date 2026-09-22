import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

/// Watches the backend for new active orders for one kitchen and blares a
/// looping alarm for [alarmSeconds] when fresh orders arrive.
///
/// Works even when push notifications fail, as long as the resto app is open.
/// First successful fetch only establishes a baseline (no alarm for old orders).
class NewOrderInfo {
  final String id;
  final double amount;
  final String address;

  NewOrderInfo({required this.id, required this.amount, required this.address});
}

class NewOrderWatcher extends ChangeNotifier {
  static const Duration pollInterval = Duration(seconds: 15);
  static const int alarmSeconds = 30;

  final ApiService _api;
  final String Function() _getKitchenId;
  final void Function(List<NewOrderInfo> freshOrders) _onNewOrders;

  Timer? _pollTimer;
  Timer? _stopTimer;
  Timer? _buzzTimer;
  AudioPlayer? _player;
  bool _alarming = false;
  bool get isAlarming => _alarming;

  Set<String> _knownIds = {};
  bool _baselined = false;
  String _lastKitchenId = '';
  bool _running = false;

  NewOrderWatcher({
    ApiService? apiService,
    required String Function() getKitchenId,
    required void Function(List<NewOrderInfo> freshOrders) onNewOrders,
  })  : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl),
        _getKitchenId = getKitchenId,
        _onNewOrders = onNewOrders;

  void start() {
    if (_running) return;
    _running = true;
    _pollTimer = Timer.periodic(pollInterval, (_) => _tick());
    _tick();
  }

  void reset() {
    _knownIds = {};
    _baselined = false;
  }

  Future<void> _tick() async {
    if (!_running) return;
    final kitchenId = _getKitchenId();
    if (kitchenId.isEmpty) return;
    try {
      final data = await _api.get(
        AppConstants.ordersEndpoint,
        queryParams: {'status': 'active'},
      );
      if (!_running) return;
      final list = (data['data'] as List?) ?? [];

      final current = <String, NewOrderInfo>{};
      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final kid = (raw['kitchen'] ?? raw['kitchenId'])?.toString() ?? '';
        if (kid != kitchenId) continue;
        final status = (raw['status'] ?? '').toString().toLowerCase();
        if (status != 'active') continue;
        final id = (raw['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final amountRaw = raw['amount'] ?? raw['total'] ?? 0;
        final amount = (amountRaw is num)
            ? amountRaw.toDouble()
            : double.tryParse(amountRaw.toString()) ?? 0.0;
        current[id] = NewOrderInfo(
          id: id,
          amount: amount,
          address: (raw['delivery_address'] ?? raw['deliveryAddress'] ?? '').toString(),
        );
      }

      if (!_baselined || _lastKitchenId != kitchenId) {
        _knownIds = current.keys.toSet();
        _baselined = true;
        _lastKitchenId = kitchenId;
        return;
      }

      final fresh = current.entries
          .where((e) => !_knownIds.contains(e.key))
          .map((e) => e.value)
          .toList();
      _knownIds = current.keys.toSet();
      if (fresh.isNotEmpty) {
        _fireAlarm();
        _onNewOrders(fresh);
      }
    } catch (e) {
      debugPrint('[NewOrderWatcher] poll failed: $e');
    }
  }

  Future<void> _fireAlarm() async {
    if (_alarming) return;
    _alarming = true;
    notifyListeners();
    try {
      await _player?.stop();
      await _player?.dispose();
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sounds/alarm.wav'));
    } catch (e) {
      debugPrint('[NewOrderWatcher] alarm play failed: $e');
    }
    _buzzTimer?.cancel();
    _buzzTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        HapticFeedback.vibrate();
      } catch (_) {}
    });
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: alarmSeconds), () => stopAlarm());
  }

  Future<void> stopAlarm() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    _buzzTimer?.cancel();
    _buzzTimer = null;
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    if (_alarming) {
      _alarming = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _running = false;
    _pollTimer?.cancel();
    _stopTimer?.cancel();
    _buzzTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
