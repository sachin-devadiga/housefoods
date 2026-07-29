import 'package:flutter/material.dart';
import '../../../../features/customer/domain/models/review_model.dart';
import '../../../../features/customer/domain/repositories/review_repository.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _reviewRepository;

  ReviewProvider(this._reviewRepository);

  List<ReviewModel> _reviews = [];
  List<ReviewModel> get reviews => _reviews;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> fetchKitchenReviews(String kitchenId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reviews = await _reviewRepository.getKitchenReviews(kitchenId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitReview({
    required ReviewModel review,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _reviewRepository.addReview(review);
      // Refresh list after successful submission
      await fetchKitchenReviews(review.kitchenId);
      onSuccess();
    } catch (e) {
      onError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
