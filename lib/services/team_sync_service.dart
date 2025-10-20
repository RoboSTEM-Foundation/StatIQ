import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_iq/services/team_search_service.dart';

class TeamSyncService {
  static const String _teamListUrl = 'https://raw.githubusercontent.com/Lavadeg31/TeamList/refs/heads/main/lib/data/master_team_list.json';
  static const String _githubToken = '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';
  static const String _lastSyncKey = 'team_list_last_sync';
  static const String _teamListKey = 'cached_team_list';
  static const Duration _syncInterval = Duration(days: 7); // Weekly sync

  /// Check if team list needs to be synced
  static Future<bool> needsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      
      if (lastSyncString == null) return true;
      
      final lastSync = DateTime.parse(lastSyncString);
      final now = DateTime.now();
      
      return now.difference(lastSync) > _syncInterval;
    } catch (e) {
      print('Error checking sync status: $e');
      return true; // Sync if we can't determine status
    }
  }

  /// Sync team list from GitHub
  static Future<bool> syncTeamList() async {
    try {
      print('🔄 Starting team list sync...');
      
      final response = await http.get(
        Uri.parse(_teamListUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'StatIQ-App/1.0',
          'Authorization': 'token $_githubToken',
        },
      );

                   if (response.statusCode == 200) {
               final teamData = json.decode(response.body);

               // Cache the data locally
               final prefs = await SharedPreferences.getInstance();
               await prefs.setString(_teamListKey, json.encode(teamData));
               await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

               // Initialize search indexes with new data
               await TeamSearchService.initializeSearchIndexes();

               print('✅ Team list synced successfully: ${teamData['teams']?.length ?? 0} teams');
               return true;
      } else if (response.statusCode == 404) {
        print('⚠️ Team list not found yet. GitHub Action may not have run yet.');
        return false;
      } else {
        print('❌ Failed to sync team list: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error syncing team list: $e');
      return false;
    }
  }

  /// Get cached team list
  static Future<List<Map<String, dynamic>>> getCachedTeamList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_teamListKey);
      
      if (cachedData != null) {
        final teamData = json.decode(cachedData);
        return List<Map<String, dynamic>>.from(teamData['teams'] ?? []);
      }
      
      return [];
    } catch (e) {
      print('Error getting cached team list: $e');
      return [];
    }
  }

  /// Search teams with efficient filtering
  static Future<List<Map<String, dynamic>>> searchTeams(String query) async {
    if (query.trim().isEmpty) return [];
    
    final teams = await getCachedTeamList();
    final lowercaseQuery = query.toLowerCase().trim();
    
    // Efficient filtering with multiple criteria
    return teams.where((team) {
      final number = (team['number'] ?? '').toString().toLowerCase();
      final name = (team['name'] ?? '').toString().toLowerCase();
      final organization = (team['organization'] ?? '').toString().toLowerCase();
      final location = (team['location'] ?? '').toString().toLowerCase();
      final city = (team['city'] ?? '').toString().toLowerCase();
      final region = (team['region'] ?? '').toString().toLowerCase();
      
      return number.contains(lowercaseQuery) ||
             name.contains(lowercaseQuery) ||
             organization.contains(lowercaseQuery) ||
             location.contains(lowercaseQuery) ||
             city.contains(lowercaseQuery) ||
             region.contains(lowercaseQuery);
    }).toList();
  }

  /// Get team by number
  static Future<Map<String, dynamic>?> getTeamByNumber(String teamNumber) async {
    final teams = await getCachedTeamList();
    try {
      return teams.firstWhere(
        (team) => team['number']?.toString().toLowerCase() == teamNumber.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get sync status info
  static Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncString = prefs.getString(_lastSyncKey);
      final teams = await getCachedTeamList();
      
      return {
        'lastSync': lastSyncString != null ? DateTime.parse(lastSyncString) : null,
        'teamCount': teams.length,
        'needsSync': await needsSync(),
        'nextSync': lastSyncString != null 
            ? DateTime.parse(lastSyncString).add(_syncInterval)
            : null,
      };
    } catch (e) {
      return {
        'lastSync': null,
        'teamCount': 0,
        'needsSync': true,
        'nextSync': null,
      };
    }
  }

  /// Force sync (for manual refresh)
  static Future<bool> forceSync() async {
    return await syncTeamList();
  }

  /// Clear cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_teamListKey);
      await prefs.remove(_lastSyncKey);
      print('🗑️ Team list cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
