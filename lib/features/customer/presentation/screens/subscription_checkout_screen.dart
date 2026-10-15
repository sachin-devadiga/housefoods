import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/address_model.dart';
import '../../domain/models/subscription_model.dart';
import '../providers/subscription_provider.dart';

/// Subscription checkout.
///
/// Calls `subscriptions/quote/` and shows the backend's breakdown verbatim.
/// The delivery fee is a separate line, never folded into the total: a weekly
/// plan is seven separate deliveries and the customer must see the plan price,
/// the meal count and the delivery charge itemised before paying.
class SubscriptionCheckoutScreen extends StatefulWidget {
  final MealPlanModel plan;
  final PlanPriceModel price;
  final AddressModel address;
  final DateTime startDate;

  const SubscriptionCheckoutScreen({
    super.key,
    required this.plan,
    required this.price,
    required this.address,
    required this.startDate,
  });

  @override
  State<SubscriptionCheckoutScreen> createState() => _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState extends State<SubscriptionCheckoutScreen> {
  SubscriptionQuoteModel? _quote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuote());
  }

  Future<void> _loadQuote() async {
    final quote = await context.read<SubscriptionProvider>().fetchQuote(
          priceId: widget.price.id,
          addressId: widget.address.id,
        );
    if (!mounted) return;
    setState(() => _quote = quote);
  }

  String _fmtDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

  String _money(double value) {
    final symbol = _quote?.currencySymbol ?? '₹';
    return '$symbol${value.toStringAsFixed(2)}';
  }

  void _pay() {
    final quote = _quote;
    if (quote == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;
    final email = profile?['email'] ?? 'customer@mealin.com';
    final phone = profile?['phone'] ?? '';

    context.read<SubscriptionProvider>().openSubscriptionCheckout(
          plan: widget.plan,
          price: widget.price,
          addressId: widget.address.id,
          startDate: widget.startDate,
          amount: quote.periodTotal,
          userEmail: email,
          userPhone: phone,
          onSuccess: (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '${widget.plan.name} subscribed. First delivery ${_fmtDate(widget.startDate)}.'),
                backgroundColor: AppTheme.secondaryColor,
              ),
            );
            Navigator.pop(context);
          },
          onError: (error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final quote = _quote;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: provider.isLoading && quote == null
          ? const Center(child: CircularProgressIndicator())
          : quote == null
              ? _buildError(provider)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildPlanCard(),
                    const SizedBox(height: 16),
                    _buildScheduleCard(quote),
                    const SizedBox(height: 16),
                    _buildBreakdownCard(quote),
                    const SizedBox(height: 16),
                    _buildDeliveryNote(),
                    const SizedBox(height: 80),
                  ],
                ),
      bottomNavigationBar: quote == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    onPressed: provider.isLoading ? null : _pay,
                    child: provider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Pay ${_money(quote.periodTotal)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildError(SubscriptionProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 14),
            Text(
              provider.error ?? 'Could not price this plan.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: _loadQuote,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.restaurant_menu, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.plan.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(widget.plan.kitchenName,
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                ],
              ),
            ),
            Text(widget.price.cadenceLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(SubscriptionQuoteModel quote) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Deliver to', widget.address.label),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(
                widget.address.fullAddress,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ),
            const Divider(height: 24),
            _row('Starts on', _fmtDate(widget.startDate)),
            const SizedBox(height: 6),
            _row('Period', '${quote.durationDays} days'),
          ],
        ),
      ),
    );
  }

  /// The itemised bill. `Delivery fee` is deliberately its own row between
  /// the plan price and the total — never merged into a single number.
  Widget _buildBreakdownCard(SubscriptionQuoteModel quote) {
    final distanceNote = quote.distanceKm == null
        ? 'distance unavailable'
        : '${quote.distanceKm!.toStringAsFixed(1)} km × ${_money(quote.deliveryFeePerKm)}/km';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bill details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _amountRow('Plan price (${quote.cadence})', quote.planPrice),
            const SizedBox(height: 6),
            _row('Meals in this period', '${quote.mealsPerPeriod}'),
            const Divider(height: 24),
            _amountRow('Delivery fee', quote.deliveryFeeTotal),
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                distanceNote,
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
            ),
            const Divider(height: 24),
            _amountRow('Total payable', quote.periodTotal, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.lightBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Each meal in this plan is delivered separately, so the delivery '
              'charge applies once per meal. The figure above is for this period.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: isBold ? 15 : 13.5, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(_money(amount),
            style: TextStyle(
              fontSize: isBold ? 16 : 13.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppTheme.primaryColor : null,
            )),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5)),
        Text(value,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  }