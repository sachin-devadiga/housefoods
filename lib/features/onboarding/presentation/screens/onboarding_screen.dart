import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/sdui/default_config.dart';
import '../../../../core/sdui/sdui_provider.dart';
import '../../../../core/sdui/sdui_types.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../onboarding/domain/models/onboarding_info.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Copy deliberately says "home kitchens", never "restaurants". Mealin's whole
  // positioning is home cooks instead of restaurants (see the Play Store
  // listing), and an onboarding screen that calls them restaurants contradicts it.
  //
  // This list is also the thing SDUI replaces in a later phase — the slides move
  // server-side so copy and order can change without an app release. Until then
  // this stays the native fallback.
  final List<OnboardingInfo> _items = [
    const OnboardingInfo(
      icon: Icons.storefront_rounded,
      title: 'Discover Home Kitchens Near You',
      description:
          'Browse real home cooks in your neighbourhood. Every meal is made in an actual home kitchen, not a restaurant.',
    ),
    const OnboardingInfo(
      icon: Icons.shopping_bag_rounded,
      title: 'Easy Ordering',
      description:
          'Order your favourite meals anytime. Add to cart, checkout, and get fast delivery to your doorstep.',
    ),
    const OnboardingInfo(
      icon: Icons.bolt_rounded,
      title: 'Fresh Food, Fast Delivery',
      description:
          'Get hot, fresh food delivered in minutes. Track your order in real-time.',
    ),
    const OnboardingInfo(
      icon: Icons.mic_rounded,
      title: 'Just Say "Hi MEAL"',
      description:
          'Order hands-free with our voice assistant. Speak your order and it does the rest.',
    ),
    const OnboardingInfo(
      icon: Icons.repeat_rounded,
      title: 'Meal Plans That Fit Your Week',
      description:
          'Subscribe to a home cook and get fresh meals on a schedule. Skip or cancel any time.',
    ),
  ];

  /// Slides from the server, or the native list when SDUI has nothing usable.
///
/// A published `onboarding` spec expresses each slide as a `section` carrying
/// `title`, `subtitle` and an icon child. Anything that does not parse is
/// skipped rather than fatal, and an empty result falls through to the native
/// slides.
List<OnboardingInfo> _sduiSlides(BuildContext context) {
  try {
    final sdui = context.read<SduiProvider>();
    final spec = sdui.specFor(SduiKeys.onboarding);
    final out = <OnboardingInfo>[];
    for (final node in spec.root.children) {
      if (node.type != SduiNodeType.section) continue;
      final title = node.title;
      if (title == null || title.trim().isEmpty) continue;

      final iconNode = node.children.isEmpty ? null : node.children.first;
      final icon = SduiIcons.resolve(iconNode?.icon) ?? Icons.fastfood_rounded;

      out.add(OnboardingInfo(
        icon: icon,
        title: title,
        description: node.subtitle ?? '',
      ));
    }
    if (out.isNotEmpty) return out;
  } catch (e) {
    // Never let a config problem block first-run.
    debugPrint('[Onboarding] SDUI slides unavailable, using native: $e');
  }
  return _items;
}

  @override
  Widget build(BuildContext context) {
    // Slides come from the `onboarding` SDUI spec when one is published, so the
    // first-run copy and ordering can change without a Play release. `_items`
    // below stays as the native fallback: onboarding is the very first screen a
    // new user sees, so it must never depend on the network or on a config
    // fetch succeeding.
    final slides = _sduiSlides(context);
    final count = slides.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: count,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 300,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 100,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(
              _items.length,
              (index) => Container(
                height: 10,
                width: _currentIndex == index ? 25 : 10,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: _currentIndex == index ? AppTheme.primaryColor : Colors.grey[300],
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 50),
            ),
            onPressed: () {
              if (_currentIndex == _items.length - 1) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
            },
            child: Text(_currentIndex == _items.length - 1 ? "Get Started" : "Next"),
          ),
        ],
      ),
    );
  }
}
