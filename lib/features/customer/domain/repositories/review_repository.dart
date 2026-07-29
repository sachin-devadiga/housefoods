import '../../../customer/domain/models/review_model.dart';

abstract class ReviewRepository {
  Future<void> addReview(ReviewModel review);
  Future<List<ReviewModel>> getKitchenReviews(String kitchenId);
}
