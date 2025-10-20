import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_iq/services/optimized_team_search.dart';

class TeamSyncService {
  static const String _teamListUrl = 'https://api.github.com/repos/Lavadeg31/teamlist/contents/lib/data/master_team_list.json';
  static const String _githubToken = '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';
  static const String _lastSyncKey = 'team_list_last_sync';
  static const String _teamListKey = 'cached_team_list';
  static const Duration _syncInterval = Duration(days: 7); // Weekly sync
  
  // Progress tracking
  static double _downloadProgress = 0.0;
  static String _downloadStatus = 'Preparing download...';

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
      _downloadProgress = 0.0;
      _downloadStatus = 'Starting download...';
      print('🔄 Starting team list sync...');
      print('📡 Fetching from: $_teamListUrl');
      
      _downloadStatus = 'Connecting to GitHub...';
      _downloadProgress = 0.1;
      
      final response = await http.get(
        Uri.parse(_teamListUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'StatIQ-App/1.0',
          'Authorization': 'token $_githubToken',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: GitHub API took too long to respond');
        },
      );

      _downloadStatus = 'Downloading team data...';
      _downloadProgress = 0.5;
      
      print('📊 Response status: ${response.statusCode}');
      print('📊 Response body length: ${response.body.length}');
      print('📊 Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        _downloadStatus = 'Parsing team data...';
        _downloadProgress = 0.7;
        
        // GitHub API returns file info
        final fileInfo = json.decode(response.body);
        final fileSize = fileInfo['size'] as int;
        print('📊 File size: $fileSize bytes');
        
        String jsonString;
        
        // For files larger than 1MB, GitHub doesn't return content directly
        if (fileSize > 1024 * 1024) {
          print('📊 File is large ($fileSize bytes), using download URL...');
          final downloadUrl = fileInfo['download_url'] as String;
          print('📊 Download URL: $downloadUrl');
          
          // Fetch the actual file content using download URL
          final downloadResponse = await http.get(
            Uri.parse(downloadUrl),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'StatIQ-App/1.0',
              'Authorization': 'token $_githubToken',
            },
          ).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Download timeout: File download took too long');
            },
          );
          
          if (downloadResponse.statusCode == 200) {
            jsonString = downloadResponse.body;
            print('📊 Downloaded content length: ${jsonString.length}');
          } else {
            throw Exception('Failed to download file: ${downloadResponse.statusCode}');
          }
        } else {
          // For small files, decode base64 content directly
          final base64Content = fileInfo['content'] as String;
          final decodedBytes = base64.decode(base64Content);
          jsonString = utf8.decode(decodedBytes);
        }
        
        final teamData = json.decode(jsonString);
        final teamCount = teamData['teams']?.length ?? 0;

        print('📊 Parsed team data: $teamCount teams');

        _downloadStatus = 'Saving to local storage...';
        _downloadProgress = 0.9;
        
        // Cache the data locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_teamListKey, json.encode(teamData));
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

        _downloadStatus = 'Initializing search engine...';
        _downloadProgress = 0.95;
        
        // Initialize optimized search with new data (with timeout)
        try {
          await OptimizedTeamSearch.initialize().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Search engine initialization timeout');
            },
          );
        } catch (e) {
          print('⚠️ Search engine initialization failed: $e');
          // Continue anyway - the data is saved, search will work on next app restart
        }

        _downloadStatus = 'Complete!';
        _downloadProgress = 1.0;
        
        print('✅ Team list synced successfully: $teamCount teams');
        return true;
      } else if (response.statusCode == 404) {
        _downloadStatus = 'Team list not found';
        _downloadProgress = 0.0;
        print('⚠️ Team list not found yet. GitHub Action may not have run yet.');
        print('🔍 URL: $_teamListUrl');
        return false;
      } else {
        _downloadStatus = 'Download failed';
        _downloadProgress = 0.0;
        print('❌ Failed to sync team list: ${response.statusCode}');
        print('📄 Response body: ${response.body.substring(0, response.body.length.clamp(0, 500))}');
        return false;
      }
    } catch (e) {
      _downloadStatus = 'Error: $e';
      _downloadProgress = 0.0;
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
  
  /// Get download progress (0.0 to 1.0)
  static double getDownloadProgress() => _downloadProgress;
  
  /// Get download status message
  static String getDownloadStatus() => _downloadStatus;
}
