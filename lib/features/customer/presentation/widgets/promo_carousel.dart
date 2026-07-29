import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../admin/presentation/providers/admin_provider.dart';
import '../../../admin/domain/models/banner_model.dart';
import '../screens/kitchen_details_screen.dart';
import '../providers/kitchen_provider.dart';

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key});

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchBanners();
    });
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final provider = context.read<AdminProvider>();
        if (provider.banners.isNotEmpty) {
          int nextPage = (_currentPage + 1) % provider.banners.length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBannerTap(BannerModel banner) {
    if (banner.actionType == 'kitchen' && banner.actionId != null) {
      final kitchens = context.read<KitchenProvider>().kitchens;
      try {
        final kitchen = kitchens.firstWhere((k) => k.id == banner.actionId);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => KitchenDetailsScreen(kitchen: kitchen)),
        );
      } catch (_) {
        // Kitchen not in current list (not loaded yet)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.banners.isEmpty) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }

        if (provider.banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: provider.banners.length,
                itemBuilder: (context, index) {
                  final map = provider.banners[index];
                  final banner = BannerModel.fromMap(map, map['id']?.toString() ?? '');
                  return GestureDetector(
                    onTap: () => _handleBannerTap(banner),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(map['image_url'] ?? map['imageUrl']),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                provider.banners.length,
                (index) => Container(
                  height: 6,
                  width: _currentPage == index ? 20 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.orange : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
