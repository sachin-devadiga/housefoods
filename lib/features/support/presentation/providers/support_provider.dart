import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';

class SupportProvider extends ChangeNotifier {
  final ApiService _api;

  SupportProvider({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _userTickets = [];
  List<Map<String, dynamic>> get userTickets => _userTickets;

  List<Map<String, dynamic>> _allTickets = [];
  List<Map<String, dynamic>> get allTickets => _allTickets;

  Future<void> raiseTicket(Map<String, dynamic> ticketData) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.post(AppConstants.supportTicketsEndpoint, body: ticketData);
    } catch (e) {
      debugPrint("Error raising ticket: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserTickets() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.supportTicketsEndpoint);
      _userTickets = ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint("Error fetching user tickets: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllTickets() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get(AppConstants.supportTicketsEndpoint);
      _allTickets = ((data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint("Error fetching all tickets: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTicketStatus(int ticketId, String newStatus) async {
    try {
      await _api.patch(
        '${AppConstants.supportTicketsEndpoint}$ticketId/',
        body: {'status': newStatus},
      );
      await fetchAllTickets();
    } catch (e) {
      debugPrint("Error updating ticket: $e");
    }
  }
}
