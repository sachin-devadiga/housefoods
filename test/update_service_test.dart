import 'package:flutter_test/flutter_test.dart';
import 'package:mealin/core/services/update_service.dart';

void main() {
  group('UpdateService.isNewer', () {
    test('1.0.4 < 1.0.5', () {
      expect(UpdateService.isNewer('1.0.5', '1.0.4'), true);
    });

    test('1.0.5 < 1.0.10', () {
      expect(UpdateService.isNewer('1.0.10', '1.0.5'), true);
    });

    test('1.1.0 > 1.0.9', () {
      expect(UpdateService.isNewer('1.1.0', '1.0.9'), true);
    });

    test('2.0.0 > 1.9.9', () {
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), true);
    });

    test('same version returns false', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.0'), false);
    });

    test('older remote returns false', () {
      expect(UpdateService.isNewer('1.0.4', '1.0.5'), false);
    });

    test('major difference', () {
      expect(UpdateService.isNewer('3.0.0', '2.9.9'), true);
    });

    test('patch-only bump', () {
      expect(UpdateService.isNewer('1.0.2', '1.0.1'), true);
    });

    test('minor-only bump', () {
      expect(UpdateService.isNewer('1.2.0', '1.1.9'), true);
    });

    test('handles different segment counts gracefully', () {
      // "1.0" treated as 1.0.0
      expect(UpdateService.isNewer('1.0.1', '1.0'), true);
      // "1" treated as 1.0.0
      expect(UpdateService.isNewer('1.0.1', '1'), true);
    });

    test('downgrade returns false', () {
      expect(UpdateService.isNewer('1.0.3', '1.0.5'), false);
    });

    test('1.0.0 vs 1.0.0 same', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.0'), false);
    });
  });

  group('UpdateService.isForceRequired', () {
    test('returns true when minVersion is newer than current', () {
      expect(UpdateService.isForceRequired('1.0.5', '1.0.3'), true);
    });

    test('returns false when current meets minVersion', () {
      expect(UpdateService.isForceRequired('1.0.3', '1.0.5'), false);
    });

    test('returns false when versions are equal', () {
      expect(UpdateService.isForceRequired('1.0.0', '1.0.0'), false);
    });

    test('returns true for major version gap', () {
      expect(UpdateService.isForceRequired('2.0.0', '1.9.9'), true);
    });
  });

  group('UpdateInfo.fromJson', () {
    test('parses valid JSON', () {
      final info = UpdateInfo.fromJson({
        'latestVersion': '1.0.5',
        'minVersion': '1.0.3',
        'updateUrl': 'https://example.com/apk',
        'updateMessage': 'Bug fixes',
        'forceUpdate': true,
      });
      expect(info.latestVersion, '1.0.5');
      expect(info.minVersion, '1.0.3');
      expect(info.updateUrl, 'https://example.com/apk');
      expect(info.updateMessage, 'Bug fixes');
      expect(info.forceUpdate, true);
    });

    test('handles missing fields with defaults', () {
      final info = UpdateInfo.fromJson({});
      expect(info.latestVersion, '1.0.0');
      expect(info.minVersion, '1.0.0');
      expect(info.updateUrl, '');
      expect(info.updateMessage, '');
      expect(info.forceUpdate, false);
    });

    test('handles null forceUpdate', () {
      final info = UpdateInfo.fromJson({
        'latestVersion': '1.0.1',
        'forceUpdate': null,
      });
      expect(info.forceUpdate, false);
    });
  });
}
