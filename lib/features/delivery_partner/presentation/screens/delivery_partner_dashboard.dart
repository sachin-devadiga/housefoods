import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/delivery_partner_provider.dart';
import 'delivery_partner_deliveries_tab.dart';
import 'delivery_document_upload_screen.dart';
import 'delivery_partner_earnings_tab.dart';
import 'delivery_partner_home_tab.dart';
import 'delivery_partner_profile_tab.dart';

class DeliveryPartnerDashboard extends StatefulWidget {
  const DeliveryPartnerDashboard({super.key});

  @override
  State<DeliveryPartnerDashboard> createState() => _DeliveryPartnerDashboardState();
}

enum _BannerState { none, uploadRequired, pendingReview }

class _DeliveryPartnerDashboardState extends State<DeliveryPartnerDashboard> {
  int _currentIndex = 0;
  _BannerState _bannerState = _BannerState.uploadRequired;
  bool _checkingDocs = true;
  late ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: AppConstants.apiBaseUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryPartnerProvider>().fetchAllData();
      _checkDocuments();
    });
  }

  Future<void> _checkDocuments() async {
    try {
      final data = await _api.get(AppConstants.deliveryAvailabilityEndpoint);
      final verified = data['is_verified'] == true;
      if (verified) {
        _bannerState = _BannerState.none;
      } else {
        final docData = await _api.get(AppConstants.deliveryDocumentsEndpoint);
        final docs = docData['data'] as List? ?? [];
        if (docs.isEmpty) {
          _bannerState = _BannerState.uploadRequired;
        } else {
          _bannerState = _BannerState.pendingReview;
        }
      }
    } catch (e) {
      _bannerState = _BannerState.uploadRequired;
    }
    if (mounted) setState(() => _checkingDocs = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const DeliveryPartnerHomeTab(),
      const DeliveryPartnerDeliveriesTab(),
      const DeliveryPartnerEarningsTab(),
      const DeliveryPartnerProfileTab(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (_bannerState != _BannerState.none && !_checkingDocs)
            SafeArea(
              top: true,
              bottom: false,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeliveryDocumentUploadScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: _bannerState == _BannerState.pendingReview ? Colors.blue.shade50 : Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(
                        _bannerState == _BannerState.pendingReview ? Icons.hourglass_top : Icons.warning_amber_rounded,
                        color: _bannerState == _BannerState.pendingReview ? Colors.blue : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bannerState == _BannerState.pendingReview
                              ? 'Documents under review — waiting for admin approval'
                              : 'Upload your documents for verification',
                          style: TextStyle(
                            color: _bannerState == _BannerState.pendingReview ? Colors.blue.shade800 : Colors.orange.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: _bannerState == _BannerState.pendingReview ? Colors.blue.shade400 : Colors.orange.shade400),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: tabs[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Available'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Deliveries'),
          BottomNavigationBarItem(icon: Icon(Icons.monetization_on), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
