import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/utils/logger.dart';

class SimpleTeamSearch {
  static const String _teamDataKey = 'cached_team_list';
  static List<Map<String, dynamic>> _allTeams = [];
  static bool _isInitialized = false;
  
  /// Initialize with cached team data
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final cachedTeamsString = prefs.getString(_teamDataKey);
    
    if (cachedTeamsString != null) {
      try {
        final Map<String, dynamic> data = json.decode(cachedTeamsString);
        _allTeams = List<Map<String, dynamic>>.from(data['teams'] ?? []);
        _isInitialized = true;
        AppLogger.d('📱 Loaded ${_allTeams.length} teams for search');
      } catch (e) {
        AppLogger.d('❌ Error loading team data: $e');
        _allTeams = [];
      }
    }
  }
  
  /// Get first N teams (for default display)
  static List<Map<String, dynamic>> getFirstTeams(int count) {
    if (!_isInitialized || _allTeams.isEmpty) {
      // Return sample teams for testing if no data is loaded
      return _getSampleTeams(count);
    }
    return _allTeams.take(count).toList();
  }
  
  /// Get sample teams for testing
  static List<Map<String, dynamic>> _getSampleTeams(int count) {
    final sampleTeams = [
      {
        'id': 1,
        'number': '2A',
        'name': 'Robosavages',
        'robotName': '',
        'organization': 'Gladstone',
        'city': 'Vancouver',
        'region': 'British Columbia',
        'country': 'Canada',
        'grade': 'Middle School',
      },
      {
        'id': 2,
        'number': '2K',
        'name': 'Gao Xinxia',
        'robotName': '',
        'organization': 'XI\'AN GAOXIN NO. 1 MIDDLE SCHOOL',
        'city': 'Xi\'an',
        'region': 'Shaanxi',
        'country': 'China',
        'grade': 'Middle School',
      },
      {
        'id': 3,
        'number': '3A',
        'name': 'Robots Squared',
        'robotName': '',
        'organization': 'MidSouth Gifted Academy',
        'city': 'Piperton',
        'region': 'Tennessee',
        'country': 'United States',
        'grade': 'Middle School',
      },
      {
        'id': 4,
        'number': '14G',
        'name': 'Marsteller',
        'robotName': '',
        'organization': 'Marsteller Middle School',
        'city': 'Bristow',
        'region': 'Virginia',
        'country': 'United States',
        'grade': 'Middle School',
      },
      {
        'id': 5,
        'number': '14H',
        'name': 'Marsteller',
        'robotName': '',
        'organization': 'Marsteller Middle School',
        'city': 'Bristow',
        'region': 'Virginia',
        'country': 'United States',
        'grade': 'Middle School',
      },
    ];
    
    return sampleTeams.take(count).toList();
  }
  
  /// Search teams using API (async version for when toggle is off)
  static Future<List<Map<String, dynamic>>> searchByAPI(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Use RobotEvents API to search for teams
      final teams = await RobotEventsAPI.searchTeams(teamNumber: query.trim());
      
      // Convert to Map format
      return teams.map((team) => {
        'id': team.id,
        'number': team.number,
        'name': team.name,
        'robotName': team.robotName,
        'organization': team.organization,
        'city': team.city,
        'region': team.region,
        'country': team.country,
        'grade': team.grade,
      }).take(limit).toList();
    } catch (e) {
      AppLogger.d('❌ Error searching teams via API: $e');
      return [];
    }
  }
  
  /// Fast team number search (sync version for cached data)
  static List<Map<String, dynamic>> searchByNumber(String query, {int limit = 50}) {
    if (!_isInitialized || _allTeams.isEmpty) return [];
    if (query.trim().isEmpty) return getFirstTeams(20);
    
    final lowerQuery = query.toLowerCase().trim();
    final results = <Map<String, dynamic>>[];
    
    // First pass: exact matches
    for (final team in _allTeams) {
      final teamNumber = (team['number'] ?? '').toString().toLowerCase();
      if (teamNumber == lowerQuery) {
        results.add(team);
        if (results.length >= limit) break;
      }
    }
    
    // Second pass: starts with matches
    if (results.length < limit) {
      for (final team in _allTeams) {
        final teamNumber = (team['number'] ?? '').toString().toLowerCase();
        if (teamNumber.startsWith(lowerQuery) && teamNumber != lowerQuery) {
          results.add(team);
          if (results.length >= limit) break;
        }
      }
    }
    
    // Third pass: contains matches
    if (results.length < limit) {
      for (final team in _allTeams) {
        final teamNumber = (team['number'] ?? '').toString().toLowerCase();
        if (teamNumber.contains(lowerQuery) && !teamNumber.startsWith(lowerQuery)) {
          results.add(team);
          if (results.length >= limit) break;
        }
      }
    }
    
    return results;
  }
  
  /// Search by name or organization (sync version for cached data)
  static List<Map<String, dynamic>> searchByName(String query, {int limit = 50}) {
    if (!_isInitialized || _allTeams.isEmpty) return [];
    if (query.trim().isEmpty) return getFirstTeams(20);
    
    final lowerQuery = query.toLowerCase().trim();
    final results = <Map<String, dynamic>>[];
    
    for (final team in _allTeams) {
      final teamName = (team['name'] ?? '').toString().toLowerCase();
      final organization = (team['organization'] ?? '').toString().toLowerCase();
      
      if (teamName.contains(lowerQuery) || organization.contains(lowerQuery)) {
        results.add(team);
        if (results.length >= limit) break;
      }
    }
    
    return results;
  }
  
  /// Get team by exact number
  static Map<String, dynamic>? getTeamByNumber(String teamNumber) {
    if (!_isInitialized || _allTeams.isEmpty) return null;
    
    final lowerNumber = teamNumber.toLowerCase();
    for (final team in _allTeams) {
      if ((team['number'] ?? '').toString().toLowerCase() == lowerNumber) {
        return team;
      }
    }
    return null;
  }
  
  /// Get total team count
  static int getTeamCount() {
    return _allTeams.length;
  }
  
  /// Check if search is ready
  static bool isReady() {
    return _isInitialized && _allTeams.isNotEmpty;
  }
  
  /// Clear all data
  static void clear() {
    _allTeams.clear();
    _isInitialized = false;
  }
}
