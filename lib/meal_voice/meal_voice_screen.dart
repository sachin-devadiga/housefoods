import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'meal_voice_controller.dart';
import 'meal_voice_state.dart';
import 'meal_voice_settings.dart';
import '../features/customer/presentation/providers/cart_provider.dart';
import '../features/customer/presentation/providers/kitchen_provider.dart';
import '../core/services/voice_order_security_service.dart';
import '../core/services/api_service.dart';
import '../core/services/token_service.dart';
import '../core/constants/app_constants.dart';
import '../features/customer/presentation/screens/voice_pin_dialog.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

/// Professional voice assistant screen for MEAL.
/// Clean, minimal interface — like a real customer-facing product.
class MealVoiceScreen extends StatefulWidget {
  const MealVoiceScreen({super.key});

  @override
  State<MealVoiceScreen> createState() => _MealVoiceScreenState();
}

class _MealVoiceScreenState extends State<MealVoiceScreen>
    with SingleTickerProviderStateMixin {
  AppLifecycleListener? _lifecycleListener;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _setupLifecycleListener();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initVoice());
  }

  Future<void> _initVoice() async {
    if (!mounted) return;
    final kitchenProvider = context.read<KitchenProvider>();
    final cartProvider = context.read<CartProvider>();
    final tokenService = TokenService();
    final token = await tokenService.getAccessToken();
    final securityService = VoiceOrderSecurityService(
      api: ApiService(baseUrl: AppConstants.apiBaseUrl),
    );
    await securityService.setToken(token);

    if (!mounted) return;
    final vc = context.read<MealVoiceController>();

    final authProvider = context.read<AuthProvider>();
    final profile = authProvider.userProfile;
    final userName = profile?['name'] as String? ?? '';
    if (userName.isNotEmpty) {
      vc.userName = userName;
      await tokenService.saveUserName(userName);
    } else {
      final storedName = await tokenService.getUserName();
      if (storedName != null && storedName.isNotEmpty) {
        vc.userName = storedName;
      }
    }

    vc.requestAuthorization = () => _showPinDialog(vc);
    final settings = MealVoiceSettings();
    await settings.load();
    await vc.initialize(
      kitchenProvider: kitchenProvider,
      cartProvider: cartProvider,
      securityService: securityService,
      settings: settings,
    );

    await vc.requestPermission();
    vc.startListening();
  }

  void _setupLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) async {
        if (!mounted) return;
        final vc = context.read<MealVoiceController>();
        switch (state) {
          case AppLifecycleState.resumed:
            vc.onAppResumed();
            break;
          case AppLifecycleState.paused:
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
          case AppLifecycleState.hidden:
            vc.onAppPaused();
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _showPinDialog(MealVoiceController vc) async {
    if (!mounted) return;
    final total = vc.searchResults.isNotEmpty
        ? vc.searchResults.fold<double>(
            0, (sum, r) => sum + (double.tryParse(r.menuItem.price.toString()) ?? 0.0))
        : 0.0;

    final token = await VoicePinDialog.show(
      context: context,
      orderTotal: total,
      orderSummary: vc.ttsResponse,
    );

    if (token != null) {
      vc.onAuthorizationGranted(token, 120);
    } else {
      vc.onAuthorizationFailed('PIN verification cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Consumer<MealVoiceController>(
        builder: (context, vc, _) {
          return CustomScrollView(
            slivers: [
              _buildAppBar(vc),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildAssistantAvatar(vc),
                    const SizedBox(height: 20),
                    _buildStatusChip(vc),
                    const SizedBox(height: 20),
                    if (vc.ttsResponse.isNotEmpty) _buildResponseCard(vc),
                    if (vc.searchResults.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSearchResultsCard(vc),
                    ],
                    if (vc.notFoundItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildNotFoundChip(vc),
                    ],
                    if (vc.awaitingConfirmation ||
                        vc.awaitingAuthorization ||
                        vc.awaitingFinalConfirmation) ...[
                      const SizedBox(height: 16),
                      _buildConfirmationCard(vc),
                    ],
                    const SizedBox(height: 24),
                    _buildMicButton(vc),
                    const SizedBox(height: 16),
                    _buildQuickActions(vc),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(MealVoiceController vc) {
    return SliverAppBar(
      expandedHeight: 56,
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'MEAL',
        style: TextStyle(
          color: Colors.deepPurple,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      centerTitle: true,
      actions: [
        if (vc.isListening)
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 28),
            onPressed: () => vc.stopListening(),
            tooltip: 'Stop listening',
          )
        else
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.green, size: 28),
            onPressed: () {
              vc.startListening();
            },
            tooltip: 'Start listening',
          ),
      ],
    );
  }

  Widget _buildAssistantAvatar(MealVoiceController vc) {
    final isActive = vc.state == MealVoiceState.listeningForWakeWord ||
        vc.state == MealVoiceState.listeningToUser;
    final isProcessing = vc.state == MealVoiceState.parsingCommand ||
        vc.state == MealVoiceState.searchingMenu ||
        vc.state == MealVoiceState.processingSpeech;
    final isError = vc.state == MealVoiceState.commandError ||
        vc.state == MealVoiceState.error;

    Color bgColor;
    IconData icon;
    if (isProcessing) {
      bgColor = Colors.orange;
      icon = Icons.hourglass_top_rounded;
    } else if (isActive) {
      bgColor = Colors.green;
      icon = Icons.mic;
    } else if (isError) {
      bgColor = Colors.redAccent;
      icon = Icons.error_outline;
    } else {
      bgColor = Colors.deepPurple;
      icon = Icons.mic_none;
    }

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isActive ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [bgColor, bgColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: bgColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 44),
        ),
      ),
    );
  }

  Widget _buildStatusChip(MealVoiceController vc) {
    final label = _getStateLabel(vc.state);
    final color = _getStateColor(vc.state);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildResponseCard(MealVoiceController vc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              vc.ttsResponse,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsCard(MealVoiceController vc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                '${vc.searchResults.length} item${vc.searchResults.length > 1 ? 's' : ''} found',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final result in vc.searchResults)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.menuItem.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          result.kitchen.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${result.menuItem.price}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotFoundChip(MealVoiceController vc) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: vc.notFoundItems.map((item) {
        return Chip(
          label: Text(item, style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.orange.shade50,
          side: BorderSide(color: Colors.orange.shade200),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildConfirmationCard(MealVoiceController vc) {
    if (vc.state == MealVoiceState.awaitingAuthorization) {
      return _confirmationBox(
        icon: Icons.security,
        color: Colors.deepPurple,
        title: 'Voice PIN Required',
        message: vc.ttsResponse,
      );
    }
    if (vc.state == MealVoiceState.authorized) {
      return _confirmationBox(
        icon: Icons.check_circle,
        color: Colors.green,
        title: 'PIN Verified',
        message: vc.ttsResponse,
      );
    }
    if (vc.state == MealVoiceState.awaitingFinalConfirmation) {
      return _confirmationBox(
        icon: Icons.help_outline,
        color: Colors.orange,
        title: 'Confirm Order',
        message: vc.ttsResponse,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _confirmationBox({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(MealVoiceController vc) {
    final isActive = vc.state == MealVoiceState.listeningToUser;
    final isWakeListening = vc.state == MealVoiceState.listeningForWakeWord;
    final isIdle = vc.state == MealVoiceState.idle || vc.state == MealVoiceState.stopped;

    return Center(
      child: GestureDetector(
        onTap: () {
          if (isIdle) {
            vc.startListening();
          } else if (isWakeListening) {
            vc.stopListening();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isActive
                  ? [Colors.redAccent, Colors.red]
                  : isWakeListening
                      ? [Colors.green, Colors.teal]
                      : [Colors.deepPurple, Colors.purple],
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive ? Colors.red : Colors.deepPurple).withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            isActive ? Icons.mic : Icons.mic_none,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(MealVoiceController vc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _quickAction(Icons.shopping_cart, 'Cart', () {
          Navigator.of(context).pop();
        }),
        const SizedBox(width: 24),
        _quickAction(Icons.restaurant, 'Menu', () {
          Navigator.of(context).pop();
        }),
        const SizedBox(width: 24),
        _quickAction(Icons.receipt_long, 'Orders', () {
          Navigator.of(context).pop();
        }),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.deepPurple, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _getStateLabel(MealVoiceState state) {
    switch (state) {
      case MealVoiceState.idle:
        return 'Tap mic to start';
      case MealVoiceState.initializing:
        return 'Setting up...';
      case MealVoiceState.listeningForWakeWord:
        return 'Say "Hi MEAL" to begin';
      case MealVoiceState.wakeDetected:
        return 'Listening...';
      case MealVoiceState.listeningToUser:
        return 'Speak now';
      case MealVoiceState.processingSpeech:
        return 'Processing...';
      case MealVoiceState.parsingCommand:
        return 'Understanding...';
      case MealVoiceState.searchingMenu:
        return 'Searching restaurants...';
      case MealVoiceState.confirmationRequired:
        return 'Say "Yes" or "No"';
      case MealVoiceState.addingToCart:
        return 'Adding to cart...';
      case MealVoiceState.commandSuccess:
        return 'Done!';
      case MealVoiceState.commandUnknown:
        return 'Try again';
      case MealVoiceState.commandError:
        return 'Something went wrong';
      case MealVoiceState.userDenied:
        return 'Cancelled';
      case MealVoiceState.stopped:
        return 'Stopped';
      case MealVoiceState.error:
        return 'Error';
      case MealVoiceState.awaitingAuthorization:
        return 'Enter Voice PIN';
      case MealVoiceState.authorized:
        return 'Verified!';
      case MealVoiceState.awaitingFinalConfirmation:
        return 'Confirm your order';
      case MealVoiceState.placingOrder:
        return 'Placing order...';
      case MealVoiceState.orderSuccess:
        return 'Order placed!';
      case MealVoiceState.orderFailed:
        return 'Order failed';
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
        return Colors.redAccent;
      case MealVoiceState.stopped:
      case MealVoiceState.userDenied:
        return Colors.grey;
      default:
        return Colors.deepPurple;
    }
  }
}
