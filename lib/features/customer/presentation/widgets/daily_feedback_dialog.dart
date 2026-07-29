import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/order_provider.dart';

class DailyFeedbackDialog extends StatefulWidget {
  final String orderId;
  final DateTime date;
  final String mealName;

  const DailyFeedbackDialog({
    super.key,
    required this.orderId,
    required this.date,
    required this.mealName,
  });

  @override
  State<DailyFeedbackDialog> createState() => _DailyFeedbackDialogState();
}

class _DailyFeedbackDialogState extends State<DailyFeedbackDialog> {
  double _rating = 5.0;
  final TextEditingController _feedbackController = TextEditingController();
  final List<String> _selectedTags = [];

  final List<String> _tags = [
    'Perfect Taste',
    'Great Portion',
    'Fresh Ingredients',
    'Timely Delivery',
    'Spicy',
    'Oily',
  ];

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _submit() async {
    final provider = context.read<OrderProvider>();
    final fullFeedback = [
      if (_selectedTags.isNotEmpty) "Tags: ${_selectedTags.join(', ')}",
      _feedbackController.text.trim(),
    ].where((e) => e.isNotEmpty).join('. ');

    try {
      await provider.submitDailyFeedback(
        orderId: widget.orderId,
        date: widget.date,
        rating: _rating,
        feedback: fullFeedback,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thank you for your feedback!"),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              "How was your meal?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              "Rate today's ${widget.mealName}",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1.0),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Quick Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _tags.map((tag) {
                bool isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) => _toggleTag(tag),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _feedbackController,
              decoration: InputDecoration(
                hintText: "Anything else you'd like to share?",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _submit,
              child: const Text("Submit Feedback"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Skip for now", style: TextStyle(color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }
}
