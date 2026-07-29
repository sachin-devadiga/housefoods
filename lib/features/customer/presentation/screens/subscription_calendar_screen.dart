import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../../domain/models/delivery_log_model.dart';
import '../providers/order_provider.dart';
import '../widgets/skip_meal_dialog.dart';

class SubscriptionCalendarScreen extends StatefulWidget {
  final OrderModel order;

  const SubscriptionCalendarScreen({super.key, required this.order});

  @override
  State<SubscriptionCalendarScreen> createState() => _SubscriptionCalendarScreenState();
}

class _SubscriptionCalendarScreenState extends State<SubscriptionCalendarScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchDeliveryLogs(widget.order.id);
    });
  }

  bool _isDateInSubscriptionRange(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(widget.order.startDate.year, widget.order.startDate.month, widget.order.startDate.day);
    final end = DateTime(widget.order.endDate.year, widget.order.endDate.month, widget.order.endDate.day);
    
    return !normalizedDate.isBefore(start) && normalizedDate.isBefore(end);
  }

  DeliveryLogModel? _findLog(List<DeliveryLogModel> logs, DateTime day) {
    for (final log in logs) {
      if (isSameDay(log.date, day)) return log;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Calendar"),
        elevation: 0,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildLegend(),
              const SizedBox(height: 10),
              TableCalendar(
                firstDay: widget.order.startDate,
                lastDay: widget.order.endDate,
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                ),
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!_isDateInSubscriptionRange(selectedDay)) return;

                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  // Check if this date is in the future and can be skipped
                  final now = DateTime.now();
                  final normalizedSelected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  final normalizedToday = DateTime(now.year, now.month, now.day);

                  if (normalizedSelected.isAfter(normalizedToday)) {
                    final log = _findLog(provider.deliveryLogs, selectedDay);
                    
                    if (log == null || log.status != 'skipped') {
                      showDialog(
                        context: context,
                        builder: (context) => SkipMealDialog(order: widget.order, date: selectedDay),
                      );
                    }
                  }
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    if (_isDateInSubscriptionRange(day)) {
                      final log = _findLog(provider.deliveryLogs, day);

                      Color color = AppTheme.primaryColor.withValues(alpha: 0.1);
                      if (log != null) {
                        if (log.status == 'skipped') color = Colors.orange;
                        if (log.status == 'delivered') color = Colors.green;
                      }

                      return Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: log != null ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const Spacer(),
              _buildSummary(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem("Active", AppTheme.primaryColor.withValues(alpha: 0.2)),
          _legendItem("Delivered", Colors.green),
          _legendItem("Skipped", Colors.orange),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Text(
              widget.order.kitchenName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap a future date to skip your meal and get a refund to your HouseWallet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
