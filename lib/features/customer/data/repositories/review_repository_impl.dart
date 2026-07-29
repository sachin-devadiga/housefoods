import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/customer/domain/models/review_model.dart';
import '../../../../features/customer/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ApiService _api;

  ReviewRepositoryImpl({ApiService? apiService})
      : _api = apiService ?? ApiService(baseUrl: AppConstants.apiBaseUrl);

  @override
  Future<void> addReview(ReviewModel review) async {
    await _api.post(AppConstants.reviewsEndpoint, body: {
      'kitchen': review.kitchenId,
      'rating': review.rating,
      'comment': review.comment,
      'customer_id': review.customerId,
      'customer_name': review.customerName,
    });
  }

  @override
  Future<List<ReviewModel>> getKitchenReviews(String kitchenId) async {
    final data = await _api.get(
      '${AppConstants.kitchenReviewsEndpoint}/$kitchenId/reviews/',
    );
    final list = (data['data'] as List?) ?? [];
    return list
        .map((e) => ReviewModel.fromMap(e as Map<String, dynamic>, e['id']?.toString() ?? ''))
        .toList();
  }
}
