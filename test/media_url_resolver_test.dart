import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/core/constants/app_constants.dart';

void main() {
  group('resolveMediaUrl', () {
    // The backend stores MEDIA-relative paths. Image widgets need an absolute
    // URL, so this is the single place that bridges the two. A regression here
    // makes every uploaded image render as the grey placeholder.
    test('prefixes a MEDIA-relative path with the API base URL', () {
      expect(
        AppConstants.resolveMediaUrl('/media/uploads/abc.jpg'),
        '${AppConstants.apiBaseUrl}/media/uploads/abc.jpg',
      );
    });

    test('adds the missing leading slash', () {
      expect(
        AppConstants.resolveMediaUrl('media/uploads/abc.jpg'),
        '${AppConstants.apiBaseUrl}/media/uploads/abc.jpg',
      );
    });

    test('leaves an absolute http(s) URL untouched', () {
      const absolute = 'https://cdn.example.com/uploads/abc.jpg';
      expect(AppConstants.resolveMediaUrl(absolute), absolute);
    });

    test('leaves a data URI untouched', () {
      const data = 'data:image/png;base64,AAAA';
      expect(AppConstants.resolveMediaUrl(data), data);
    });

    test('returns empty for null and blank input', () {
      expect(AppConstants.resolveMediaUrl(null), '');
      expect(AppConstants.resolveMediaUrl(''), '');
      expect(AppConstants.resolveMediaUrl('   '), '');
    });

    test('does not double up slashes when the base URL has a trailing slash', () {
      // apiBaseUrl is configurable at build time, so this shape is reachable.
      final original = AppConstants.apiBaseUrl;
      AppConstants.apiBaseUrl = 'https://example.test/';
      addTearDown(() => AppConstants.apiBaseUrl = original);

      expect(
        AppConstants.resolveMediaUrl('/media/uploads/abc.jpg'),
        'https://example.test/media/uploads/abc.jpg',
      );
    });
  });
}