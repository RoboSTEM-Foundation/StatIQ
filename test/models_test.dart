import 'package:flutter_test/flutter_test.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';

void main() {
  group('Team Model Tests', () {
    test('should create team from JSON', () {
      final json = {
        'id': 12345,
        'number': '12345A',
        'team_name': 'Test Team',
        'organization': 'Test School',
        'location': {
          'city': 'Test City',
          'region': 'Test Region',
          'country': 'Test Country',
        },
        'grade': 'Middle School',
        'program': {'id': 41, 'name': 'VEX IQ Challenge'},
        'team_type': 'Team',
        'registered': true,
      };

      final team = Team.fromJson(json);
      
      expect(team.id, 12345);
      expect(team.number, '12345A');
      expect(team.name, 'Test Team');
      expect(team.organization, 'Test School');
      expect(team.city, 'Test City');
      expect(team.region, 'Test Region');
      expect(team.country, 'Test Country');
      expect(team.grade, 'Middle School');
      expect(team.registered, true);
    });

    test('should handle missing fields gracefully', () {
      final json = {
        'id': 12345,
        'number': '12345A',
      };

      final team = Team.fromJson(json);
      
      expect(team.id, 12345);
      expect(team.number, '12345A');
      expect(team.name, '');
      expect(team.organization, '');
      expect(team.city, '');
      expect(team.region, '');
      expect(team.country, '');
      expect(team.grade, '');
      expect(team.registered, false);
    });
  });

  group('Event Model Tests', () {
    test('should create event from JSON', () {
      final json = {
        'id': 67890,
        'sku': 'RE-VIQRC-25-0303',
        'name': 'Test Event',
        'start': '2025-03-15T09:00:00Z',
        'end': '2025-03-15T17:00:00Z',
        'location': {
          'venue': 'Test Venue',
          'city': 'Test City',
          'region': 'Test Region',
          'country': 'Test Country',
        },
        'level_class': 'Elementary School',
        'season': {'id': 196, 'name': 'Mix & Match'},
        'program': {'id': 41, 'name': 'VEX IQ Challenge'},
      };

      final event = Event.fromJson(json);
      
      expect(event.id, 67890);
      expect(event.sku, 'RE-VIQRC-25-0303');
      expect(event.name, 'Test Event');
      expect(event.location, isNotEmpty);
      expect(event.city, 'Test City');
      expect(event.region, 'Test Region');
      expect(event.country, 'Test Country');
      expect(event.levelClassName, 'Elementary School');
    });

    test('should handle missing fields gracefully', () {
      final json = {
        'id': 67890,
        'sku': 'RE-VIQRC-25-0303',
        'name': 'Test Event',
      };

      final event = Event.fromJson(json);
      
      expect(event.id, 67890);
      expect(event.sku, 'RE-VIQRC-25-0303');
      expect(event.name, 'Test Event');
      expect(event.location, '');
      expect(event.city, '');
      expect(event.region, '');
      expect(event.country, '');
      expect(event.levelClassName, '');
    });
  });
}
