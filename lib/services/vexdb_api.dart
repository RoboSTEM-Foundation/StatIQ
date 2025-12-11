import 'dart:convert';
import 'package:http/http.dart' as http;

class VexDBAPI {
  static const String baseUrl = 'https://vexdb.io/v1';
  
  // Fetch VEX IQ world skills rankings for a specific team
  static Future<Map<String, dynamic>?> getTeamSkillsData({
    required String teamNumber,
    int? seasonId,
  }) async {
    try {
      AppLogger.d('=== VexDB Skills Lookup for $teamNumber ===');
      
      // VexDB skills endpoint: GET /v1/skills?program=VIQRC&team={number}
      final params = <String, String>{
        'program': 'VIQRC', // VEX IQ Robotics Competition
        'team': teamNumber,
      };
      
      // Add season filter if provided
      if (seasonId != null) {
        // Map season IDs to VexDB season names
        final seasonName = _getVexDBSeasonName(seasonId);
        if (seasonName != null) {
          params['season'] = seasonName;
        }
      }
      
      final uri = Uri.parse('$baseUrl/skills').replace(queryParameters: params);
      AppLogger.d('VexDB API Request: $uri');
      
      final response = await http.get(uri);
      AppLogger.d('VexDB Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['result'] as List<dynamic>?;
        
        if (results != null && results.isNotEmpty) {
          // Return the best skills score for this team
          final skillsData = results.first as Map<String, dynamic>;
          AppLogger.d('Found VexDB skills data: $skillsData');
          return skillsData;
        } else {
          AppLogger.d('No VexDB skills data found for team $teamNumber');
        }
      } else {
        AppLogger.d('VexDB API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppLogger.d('Error fetching VexDB skills data: $e');
    }
    
    AppLogger.d('=== End VexDB Skills Lookup ===');
    return null;
  }
  
  // Get VEX IQ world skills rankings for percentage calculation
  static Future<List<Map<String, dynamic>>> getWorldSkillsRankings({
    String program = 'VIQRC',
    String? grade,
    int limit = 1000,
  }) async {
    try {
      AppLogger.d('=== VexDB World Skills Rankings ===');
      
      final params = <String, String>{
        'program': program,
        'limit': limit.toString(),
      };
      
      if (grade != null) {
        params['grade'] = grade;
      }
      
      final uri = Uri.parse('$baseUrl/skills').replace(queryParameters: params);
      AppLogger.d('VexDB World Rankings Request: $uri');
      
      final response = await http.get(uri);
      AppLogger.d('VexDB World Rankings Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['result'] as List<dynamic>? ?? [];
        
        AppLogger.d('Found ${results.length} world skills entries');
        return results.cast<Map<String, dynamic>>();
      } else {
        AppLogger.d('VexDB World Rankings error: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.d('Error fetching VexDB world rankings: $e');
    }
    
    AppLogger.d('=== End VexDB World Skills Rankings ===');
    return [];
  }
  
  // Calculate world skills percentile ranking
  static Future<double> calculateSkillsPercentile({
    required int teamScore,
    String? grade,
  }) async {
    try {
      final worldRankings = await getWorldSkillsRankings(grade: grade);
      
      if (worldRankings.isEmpty) {
        return 0.0;
      }
      
      // Count how many teams this team beats
      int teamsBeaten = 0;
      for (final ranking in worldRankings) {
        final score = ranking['score'] as int? ?? 0;
        if (teamScore > score) {
          teamsBeaten++;
        }
      }
      
      // Calculate percentile
      final percentile = (teamsBeaten / worldRankings.length) * 100;
      AppLogger.d('Team score $teamScore beats $teamsBeaten/${worldRankings.length} teams = ${percentile.toStringAsFixed(1)}%');
      
      return percentile;
    } catch (e) {
      AppLogger.d('Error calculating skills percentile: $e');
      return 0.0;
    }
  }
  
  // Map RobotEvents season IDs to VexDB season names
  static String? _getVexDBSeasonName(int seasonId) {
    switch (seasonId) {
      case 196: return 'Mix and Match'; // 2025-2026
      case 189: return 'Rapid Relay';   // 2024-2025
      case 180: return 'Full Volume';   // 2023-2024
      case 173: return 'Pitching In';   // 2022-2023
      case 156: return 'Slapshot';      // 2021-2022
      default: return null;
    }
  }
  
  // Convert VexDB skills data to our format
  static Map<String, dynamic> convertVexDBSkillsData(Map<String, dynamic> vexdbData) {
    return {
      'id': vexdbData['id'] ?? 0,
      'team': {
        'id': 0,
        'name': vexdbData['team'] ?? '',
      },
      'type': 'combined', // VexDB typically returns combined scores
      'season_id': 0,
      'score': vexdbData['score'] ?? 0,
      'driver_score': vexdbData['driver'] ?? 0,
      'programming_score': vexdbData['programming'] ?? 0,
      'highest_driver': vexdbData['maxdriver'] ?? 0,
      'highest_programming': vexdbData['maxprogramming'] ?? 0,
      'attempts': (vexdbData['attempts'] ?? 0),
      'event': {
        'id': 0,
        'name': vexdbData['sku'] ?? '',
        'code': vexdbData['sku'] ?? '',
      },
    };
  }
} 