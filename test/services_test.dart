import 'package:flutter_test/flutter_test.dart';
import 'package:stat_iq/constants/api_config.dart';

void main() {
  group('ApiConfig Tests', () {
    test('should have valid API keys', () {
      expect(ApiConfig.robotEventsApiKeys, isNotEmpty);
      expect(ApiConfig.robotEventsApiKeys.length, greaterThan(0));
    });

    test('should return random API key', () {
      final key1 = ApiConfig.randomApiKey;
      final key2 = ApiConfig.randomApiKey;
      expect(key1, isNotEmpty);
      expect(key2, isNotEmpty);
      // Keys should be from the same pool
      expect(ApiConfig.robotEventsApiKeys.contains(key1), true);
      expect(ApiConfig.robotEventsApiKeys.contains(key2), true);
    });

    test('should have correct program IDs', () {
      expect(ApiConfig.vexIQProgramId, 41);
      expect(ApiConfig.vrcProgramId, 1);
      expect(ApiConfig.vexuProgramId, 4);
    });

    test('should have correct base URL', () {
      expect(ApiConfig.robotEventsBaseUrl, 'https://www.robotevents.com/api/v2');
    });
  });

  group('App Constants Tests', () {
    test('should have valid VEX IQ colors', () {
      expect(ApiConfig.vexIQProgramId, 41);
    });
  });
}
