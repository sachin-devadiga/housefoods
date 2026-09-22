import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/presentation/screens/kitchen_details_screen.dart';
import '../../../customer/domain/models/kitchen_model.dart';
import '../../domain/models/ai_chat_models.dart';
import '../providers/ai_chat_provider.dart';
import '../../../../meal_voice/sarvam_stt_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SarvamSTTService? _sttService;
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;

  bool _pendingOrderConfirmation = false;
  Map<String, dynamic>? _pendingOrderData;

  @override
  void initState() {
    super.initState();
    _initVoice();
  }

  Future<void> _initVoice() async {
    _sttService = SarvamSTTService();
    await _sttService!.initialize();

    _recorder = FlutterSoundRecorder();
    try {
      await _recorder!.openRecorder();
      _isRecorderInitialized = true;
    } catch (e) {
      debugPrint('[AiChat] Recorder init failed: $e');
      _isRecorderInitialized = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recorder?.closeRecorder();
    _sttService?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(AiChatProvider provider) {
    final text = _controller.text.trim();
    if (text.isEmpty || provider.isLoading) return;

    _controller.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _toggleRecording(AiChatProvider provider) async {
    if (_isRecording) {
      await _stopRecording(provider);
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }

    if (!_isRecorderInitialized || _sttService == null || !_sttService!.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice service not ready')),
        );
      }
      return;
    }

    try {
      await _recorder!.startRecorder(
        toFile: 'ai_chat_voice_${DateTime.now().millisecondsSinceEpoch}.wav',
        codec: Codec.pcm16WAV,
      );
      setState(() => _isRecording = true);
      _sttService!.setRecording(true);
    } catch (e) {
      debugPrint('[AiChat] Start recording error: $e');
    }
  }

  Future<void> _stopRecording(AiChatProvider provider) async {
    try {
      final path = await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      _sttService!.setRecording(false);

      if (path != null && path.isNotEmpty) {
        final result = await _sttService!.transcribeFile(path);
        if (result != null && result.transcript.isNotEmpty) {
          _controller.text = result.transcript;
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not transcribe audio')),
          );
        }
      }
    } catch (e) {
      debugPrint('[AiChat] Stop recording error: $e');
      setState(() => _isRecording = false);
    }
  }

  void _handleConfirmOrder() {
    if (_pendingOrderData == null) return;
    final provider = context.read<AiChatProvider>();
    provider.sendMessage('confirm order');
    setState(() {
      _pendingOrderConfirmation = false;
      _pendingOrderData = null;
    });
    _scrollToBottom();
  }

  void _handleCancelOrder() {
    setState(() {
      _pendingOrderConfirmation = false;
      _pendingOrderData = null;
    });
    final provider = context.read<AiChatProvider>();
    provider.sendMessage('cancel order');
    _scrollToBottom();
  }

  void _handleAddToCart(String itemName, String? itemId) {
    final provider = context.read<AiChatProvider>();
    final msg = itemId != null
        ? 'Add item $itemId ($itemName) to my cart with quantity 1'
        : 'Add $itemName to my cart';
    _controller.clear();
    provider.sendMessage(msg);
    _scrollToBottom();
  }

  void _handleViewMenu(String kitchenId, String kitchenName) {
    final provider = context.read<AiChatProvider>();
    final msg = 'Show me the full menu of $kitchenName restaurant';
    _controller.clear();
    provider.sendMessage(msg);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MEAL AI',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Retry last message',
            onPressed: () {
              final provider = context.read<AiChatProvider>();
              provider.retryLastMessage();
              _scrollToBottom();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Conversation'),
                  content: const Text('Start a new conversation?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<AiChatProvider>().clearConversation();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AiChatProvider>(
              builder: (context, provider, child) {
                if (provider.messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: provider.messages.length +
                      (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.messages.length) {
                      return _buildTypingIndicator();
                    }

                    final message = provider.messages[index];
                    final isLastAssistant = index == provider.messages.length - 1 &&
                        message.role == 'assistant' &&
                        !provider.isLoading;
                    return _buildMessageBubble(message, isLastAssistant, provider);
                  },
                );
              },
            ),
          ),
          _buildErrorBanner(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            const Text(
              'MEAL AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about food, restaurants, or your orders',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('What should I eat today?'),
                _buildSuggestionChip('Show me top rated restaurants'),
                _buildSuggestionChip('Recommend healthy options'),
                _buildSuggestionChip('Track my last order'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
      onPressed: () {
        _controller.text = text;
        final provider = context.read<AiChatProvider>();
        _sendMessage(provider);
      },
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      side: BorderSide(
        color: AppTheme.primaryColor.withValues(alpha: 0.2),
      ),
      labelStyle: TextStyle(color: AppTheme.primaryColor.withValues(alpha: 0.8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  Widget _buildMessageBubble(AiChatMessage message, bool isLastAssistant, AiChatProvider provider) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primaryColor
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
            ...message.toolResults.map((result) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildToolResultCard(result),
                )),
            if (isLastAssistant && provider.lastUserMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () {
                    provider.retryLastMessage();
                    _scrollToBottom();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolResultCard(AiToolResult result) {
    final data = result.result;

    // list_restaurants tool → show restaurant cards
    if (result.toolName == 'list_restaurants') {
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: results
              .take(5)
              .map((r) => _buildRestaurantCard(r as Map<String, dynamic>))
              .toList(),
        ),
      );
    }

    // search_food tool → show food item cards
    if (result.toolName == 'search_food') {
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: results
              .take(5)
              .map((i) => _buildItemCard(i as Map<String, dynamic>))
              .toList(),
        ),
      );
    }

    if (result.toolName == 'get_cart' ||
        result.toolName == 'add_to_cart') {
      return SizedBox(
        width: double.infinity,
        child: _buildCartSummaryCard(data),
      );
    }

    if (result.toolName == 'place_order' ||
        result.toolName == 'validate_order') {
      final needsConfirmation = data['needs_confirmation'] == true ||
          data['confirmed'] != true;
      if (needsConfirmation) {
        setState(() {
          _pendingOrderConfirmation = true;
          _pendingOrderData = data;
        });
      }
      return SizedBox(
        width: double.infinity,
        child: _buildOrderConfirmationCard(data),
      );
    }

    if (result.toolName == 'get_restaurant_details') {
      final menuItems = data['menu_items'] as List<dynamic>? ?? [];
      if (menuItems.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['name'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  data['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ...menuItems
                .take(5)
                .map((i) => _buildItemCard(i as Map<String, dynamic>))
                .toList(),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final kitchenId = restaurant['restaurant_id']?.toString() ?? restaurant['id']?.toString();
    final kitchenName = restaurant['restaurant_name'] ?? restaurant['name'] ?? 'Restaurant';
    final rating = restaurant['rating'] ?? 0;
    final totalRatings = restaurant['total_ratings'] ?? 0;
    final distance = restaurant['distance_km'];
    final eta = restaurant['estimated_minutes'];
    final menuCount = restaurant['menu_items_count'] ?? 0;
    final imageUrl = restaurant['image_url'] ?? restaurant['image'];
    final isVeg = restaurant['is_veg'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.restaurant,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.restaurant,
                          color: AppTheme.primaryColor,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              kitchenName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isVeg)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('VEG', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (rating > 0) ...[
                            Icon(Icons.star, size: 14, color: Colors.amber[600]),
                            const SizedBox(width: 2),
                            Text(
                              '$rating',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            if (totalRatings > 0)
                              Text(
                                ' ($totalRatings)',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            const SizedBox(width: 8),
                          ],
                          if (distance != null)
                            Text(
                              '${distance} km',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          if (eta != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 2),
                            Text(
                              '$eta min',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                      if (menuCount > 0)
                        Text(
                          '$menuCount items on menu',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (kitchenId != null && kitchenId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleViewMenu(kitchenId, kitchenName),
                    icon: const Icon(Icons.restaurant_menu, size: 16),
                    label: const Text('View Menu', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final isVeg = item['is_veg'] == true;
    final itemName = item['item_name'] ?? item['name'] ?? 'Item';
    final itemId = (item['item_id'] ?? item['id'])?.toString();
    final restaurantName = item['restaurant_name'] ?? item['restaurant'];
    final rating = item['rating'];
    final eta = item['estimated_minutes'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isVeg ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      if (restaurantName != null)
                        Text(
                          restaurantName.toString(),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      if (rating != null && rating > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 12, color: Colors.amber[600]),
                        const SizedBox(width: 2),
                        Text('$rating', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                      if (eta != null) ...[
                        const SizedBox(width: 8),
                        Text('${eta} min', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '₹${item['price'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _handleAddToCart(itemName, itemId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummaryCard(Map<String, dynamic> cart) {
    final items = cart['items'] as List<dynamic>? ?? [];
    final total = cart['total'] ?? cart['subtotal'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cart Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Divider(),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['name'] ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        'x${item['quantity'] ?? 1}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '₹${item['price'] ?? item['item_total'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '₹$total',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderConfirmationCard(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    final restaurant = order['restaurant'] ?? order['kitchen_name'] ?? '';
    final deliveryAddress = order['delivery_address'] ?? '';
    final paymentMethod = order['payment_method'] ?? '';
    final subtotal = order['subtotal'] ?? 0;
    final tax = order['tax'] ?? 0;
    final deliveryFee = order['delivery_fee'] ?? 0;
    final total = order['total'] ?? 0;

    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                const Text(
                  'Order Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(),
            if (restaurant.toString().isNotEmpty)
              _buildDetailRow('Restaurant', '$restaurant'),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Items:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              ...items.map((item) {
                final name = item['name'] ?? item['item'] ?? '';
                final qty = item['quantity'] ?? 1;
                final price = item['price'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name x$qty',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const Divider(),
            if (subtotal != 0) _buildDetailRow('Subtotal', '₹$subtotal'),
            if (tax != 0) _buildDetailRow('Tax', '₹$tax'),
            if (deliveryFee != 0) _buildDetailRow('Delivery', '₹$deliveryFee'),
            _buildDetailRow('Total', '₹$total'),
            if (paymentMethod.toString().isNotEmpty)
              _buildDetailRow('Payment', '$paymentMethod'),
            if (deliveryAddress.toString().isNotEmpty)
              _buildDetailRow('Delivery', '$deliveryAddress'),
            if (_pendingOrderConfirmation) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleCancelOrder,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleConfirmOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Confirm Order',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Consumer<AiChatProvider>(
      builder: (context, provider, child) {
        if (provider.error == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: AppTheme.errorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.error!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => provider.clearError(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Consumer<AiChatProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Listening...' : 'Ask MEAL AI...',
                      hintStyle: TextStyle(
                        color: _isRecording ? AppTheme.errorColor : Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isRecording
                          ? AppTheme.errorColor.withValues(alpha: 0.08)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(provider),
                  ),
                ),
                const SizedBox(width: 6),
                _buildMicButton(provider),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: provider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: provider.isLoading
                        ? null
                        : () => _sendMessage(provider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicButton(AiChatProvider provider) {
    if (!_isRecorderInitialized) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _isRecording ? AppTheme.errorColor : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: _isRecording
            ? const Icon(Icons.mic, color: Colors.white, size: 20)
            : Icon(Icons.mic_none, color: Colors.grey[600], size: 20),
        onPressed: provider.isLoading ? null : () => _toggleRecording(provider),
      ),
    );
  }
}
