import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../widgets/daily_feedback_dialog.dart';

class LiveTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const LiveTrackingScreen({super.key, required this.order});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final ApiService _api = ApiService(baseUrl: AppConstants.apiBaseUrl);
  String _currentStatus = '';
  bool _feedbackPrompted = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await _api.get('${AppConstants.orderStatusEndpoint}/${widget.order.id}/');
      final status = data['status'] as String? ?? _currentStatus;
      if (status != _currentStatus) {
        setState(() => _currentStatus = status);
      }
      if (status == 'delivered' && !_feedbackPrompted) {
        _feedbackPrompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showFeedbackDialog());
      }
    } catch (_) {}
  }

  void _showFeedbackDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyFeedbackDialog(
        orderId: widget.order.id,
        date: DateTime.now(),
        mealName: widget.order.mealType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Daily Meal"),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[200],
              child: Stack(
                children: [
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 64, color: Colors.grey),
                        Text("Map View"),
                        Text("(Integrate Google Maps API Key)", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      onPressed: () {},
                      backgroundColor: Colors.white,
                      mini: true,
                      child: const Icon(Icons.my_location, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKitchenInfo(),
                    const Divider(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Delivery Status",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_currentStatus == 'Delivered')
                          TextButton.icon(
                            onPressed: _showFeedbackDialog,
                            icon: const Icon(Icons.star_outline, size: 16),
                            label: const Text("Rate Meal", style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildStepper(_currentStatus),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: const Icon(Icons.restaurant, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.order.kitchenName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Meal: ${widget.order.mealType.toUpperCase()}",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.call, color: AppTheme.secondaryColor),
        ),
      ],
    );
  }

  Widget _buildStepper(String status) {
    final List<Map<String, dynamic>> steps = [
      {"title": "Order Active", "key": "active", "icon": Icons.check_circle},
      {"title": "Preparing your meal", "key": "Preparing", "icon": Icons.soup_kitchen},
      {"title": "Out for delivery", "key": "Out for Delivery", "icon": Icons.delivery_dining},
      {"title": "Delivered", "key": "Delivered", "icon": Icons.home},
    ];

    int currentStepIndex = steps.indexWhere((s) => s['key'] == status);
    if (currentStepIndex == -1) currentStepIndex = 0;

    return Column(
      children: List.generate(steps.length, (index) {
        bool isCompleted = index <= currentStepIndex;
        bool isCurrent = index == currentStepIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  steps[index]['icon'],
                  color: isCompleted ? AppTheme.secondaryColor : Colors.grey[300],
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? AppTheme.secondaryColor : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps[index]['title'],
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _getStatusDescription(status),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'active': return "Your subscription is confirmed.";
      case 'Preparing': return "Chef is preparing your healthy meal.";
      case 'Out for Delivery': return "Our partner is on the way to your door.";
      case 'Delivered': return "Enjoy your meal! See you tomorrow.";
      default: return "Processing your order...";
    }
  }
}
