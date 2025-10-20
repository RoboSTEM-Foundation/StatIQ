import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class ApiConfig {
  // RobotEvents API Configuration
  static const String robotEventsBaseUrl = 'https://www.robotevents.com/api/v2';
  
  // RobotEvents API keys - multiple keys for load distribution and rate limit avoidance
  // 🚀 Ready for 5 API keys from different teams/accounts for optimal load distribution
  static const List<String> robotEventsApiKeys = [
    // API Key #1 - Primary (alex @1698v)
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzIiwianRpIjoiNTJhYzMzZjc3NmQwMzg1NjA2ZjM5YzZlZjNlNjQ5OWI5Y2JkYzNjZmY3YTM2ZjU4NzMzYjU4MmIxZjZhYzY4ZGMyODVlYmRhNDhlMzM2M2MiLCJpYXQiOjE3NDg0ODM2MjIuNDQ3MjgyMSwibmJmIjoxNzQ4NDgzNjIyLjQ0NzI4NCwiZXhwIjoyNjk1MTY4NDIyLjQ0MTMzNjIsInN1YiI6IjEzOTU1OCIsInNjb3BlcyI6W119.Lk119Jqi64rRqvCLSCyS_Rc72Ee-oVjxRS9FB8Qs3Q3_DaXm7B2YT_BUEgNGMyRBLHXTeOeTWUAXoqt-7p41LU7ZJ8Q-rFRXDomyh4IOooTS04HjxdOgE_UCncXGwctwkh_E31p2Bw1u6K4BnJ0vZJLpK-uydOXteLLb4-YCKnBQM5PiZrpSZMSbuUyKNVfg_cKlofTsq_2aiPIWR-e0AeT-zEF5uJzGbpFOGJU1Jz2RejTFb26PUq6KcaPxuppu1OTnhFYBaPwZZBtjpHdr24lWyG6Pb-GtaV4Sn0l5_fSo-eoXT_bAMx1vgIqXoS03aja1IRLdIYlMQR7eMlXB5eAJBMgA0AzIRFg8fm4IFmTDHHxykyQmDnKUeFKE50jYiYDJjEx5MDCuso1tHQaEQt38ucL_t7UegPaoGYa4MkhPUQZIieftvskTopi7jsy78IfF76pRI6OPZOjqjbdDfpFhtz2zCxypx-x3qNq1hlDNOf0szkozxQxlHpWx2KMhfAUAwJk3IHA0_o2RTCk0r4vAMP_8RKrRodkIS93cqyB_r9uZLIAHyvMKOOg2Du8qKQBKY1lK8Zke68WidiP6Ggl_iQxItAEkfxgVZ0ElK9N6fPzWJ94hvJCnbn0EcG9CHAlOnDHUfr74ZFaGWlQGx_EsWQxX1l3ZBmmp3AmmwQo',
    
    // API Key #2 - Secondary (jason @2982_x)
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIzIiwianRpIjoiZWI3NTdiMzJiMzUzMTAyNjA1NTBhMGVkOTM2NjAzMTg3NjZmNDA1NjBiNjQ1YzJiZTgzN2JhZDExODZlYjRmYTRjMTBlODUyZGNmZTg2OWUiLCJpYXQiOjE3NTE3MzQzMDMuOTIwODM5MSwibmJmIjoxNzUxNzM0MzAzLjkyMDg0MSwiZXhwIjoyNjk4NDE5MTAzLjkxNTEyMTEsInN1YiI6IjEyNTM1OCIsInNjb3BlcyI6W119.Ax_91SuJvOVjBPijWTlPUkXEQjl2wQf1XYXJIwQC3CbxEItBytmV0gQlQldTPcNa9Tsd9fWjf6bvyyd2Ddnt_ZtyJW6-ZGKPavoTcoV_T9y8TvcdsD1ABYRtWJG76FNirdTspFd9bVNOWdRwp2x_iUXPAG8gk_VJ0OMNdSm9Q59SI51lR31-Tq2jdKmzzozkGkiJ05L_7qS1_2RJP4RpwxBHjyB-lc-riRul-t9x1fDTsa9CmPmNj3t6O4vjg7en7teToCRsdSLOT-SfL6wBmmsaXGLKmIjDPbsFvzxS93XroiOTMzjfImft0g5eOR_qhq4Tn9H6Z3M_xNkFQ3ILB9AYsYr8IzOeNkNRxOu35RAxISDE-gevGdWSwGHhVPjSVfzkPTJBxg-QQB8fp_dAHfUQG8e0SGKohXA6-A2mTjcJQb8eFeKG2bC2Sgb_LIjyeyHpKP_BZ87TAe_MLpvU0MN49zdswO2L5FQlUigUzhbUM7ROWDdjgEH2Hy9rgZ5aCLBvJ4ZQEZW8UH1UU68u-D0MJCcFc16RsUUWBAEAQ1A6lFCW-9Pc6owYFBYu77OUq_PwW13KJ6pTzmX123SBRwYVMFAow3i4WYh1g4IGuA-k1MAuJwtQWK70jSgB6Ro-LUC-sweDXQ3zfxIcT6ni2lTnPX2Otm8tULaVzGOl9O8',
    
    // 🔑 ADD MORE API KEYS HERE WHEN AVAILABLE:
    // 'API_KEY_3_FROM_TEAM_3', // Team 3 API key
    // 'API_KEY_4_FROM_TEAM_4', // Team 4 API key  
    // 'API_KEY_5_FROM_TEAM_5', // Team 5 API key
  ];
  
  // Random number generator for API key selection
  static final Random _random = Random();
  
  // Get a random API key for load distribution
  static String get randomApiKey {
    final selectedKey = robotEventsApiKeys[_random.nextInt(robotEventsApiKeys.length)];
    final keyIndex = robotEventsApiKeys.indexOf(selectedKey) + 1;
    print('🔑 Using API Key #$keyIndex/${robotEventsApiKeys.length} for request');
    return selectedKey;
  }
  
  // Legacy getter for backward compatibility (now returns random key)
  static String get robotEventsApiKey => randomApiKey;
  
  // Program IDs (based on RobotEvents API)
  static const int vrcProgramId = 1;       // VRC (V5)
  static const int vexuProgramId = 4;      // VEXU (College)
  static const int vexIQProgramId = 41;    // VEX IQ
  
  // Dynamic season ID storage (matches Swift implementation)
  // season_id_map[program_index][season_id] = season_name
  // program_index: 0=VRC, 1=VEXU, 2=VEX_IQ
  static Map<int, Map<int, String>> seasonIdMap = {
    0: {}, // VRC seasons  
    1: {}, // VEXU seasons
    2: {}, // VEX IQ seasons
  };
  
  // Current selected season IDs (default to current season)
  static int currentVexIQSeasonId = 196; // VEX IQ 2025-2026: Mix & Match (current)
  static int currentVRCSeasonId = 197;   // VRC 2025-2026: Push Back
  static int currentVEXUSeasonId = 198;  // VEXU 2025-2026: Push Back
  
  // Available VEX IQ seasons for selection (current season first)
  static Map<String, Map<String, int>> availableSeasons = {
    'Mix & Match (2025-2026)': {'vexiq': 196},    // Current season
    'Rapid Relay (2024-2025)': {'vexiq': 189},    // Previous season - has competition data
    'Full Volume (2023-2024)': {'vexiq': 180},    // Older season - has data
  };
  
  // Display names for current season
  static const String currentSeasonName = 'Mix & Match (2025-2026)';
  static const String currentGameName = 'Mix & Match';
  
  // VEX IQ Season IDs by grade level
  static const Map<String, int> vexIQSeasonIds = {
    'Elementary School': 196, // Mix & Match 2025-2026
    'Middle School': 196,     // Mix & Match 2025-2026 (same for both)
  };
  
  // API Headers (matches Swift implementation)
  static Map<String, String> get robotEventsHeaders => {
    'Authorization': 'Bearer $robotEventsApiKey',
    'Content-Type': 'application/json',
  };
  
  // API Configuration
  static const int defaultPageSize = 250; // Matches Swift implementation
  static const int maxPageSize = 250;
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Query parameters (matches Swift robotevents_request function)
  static Map<String, dynamic> get defaultParams => {
    'per_page': defaultPageSize,
  };
  
  // Generate season ID map from API (matches Swift implementation)
  static Future<void> generateSeasonIdMap() async {
    print('=== Generating Season ID Map ===');
    try {
      final response = await http.get(
        Uri.parse('$robotEventsBaseUrl/seasons/'),
        headers: robotEventsHeaders,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final seasonsData = jsonData['data'] as List<dynamic>;
        
        // Clear existing mappings
        seasonIdMap = {0: {}, 1: {}, 2: {}};
        
        for (final seasonData in seasonsData) {
          final programData = seasonData['program'] as Map<String, dynamic>;
          final programId = programData['id'] as int;
          final seasonId = seasonData['id'] as int;
          final seasonName = seasonData['name'] as String;
          
          // Map program ID to index (matches Swift logic)
          int gradeIndex;
          switch (programId) {
            case 1:  // VRC
              gradeIndex = 0;
              break;
            case 4:  // VEXU  
              gradeIndex = 1;
              break;
            case 41: // VEX IQ
              gradeIndex = 2;
              break;
            default:
              continue; // Skip unknown programs
          }
          
          seasonIdMap[gradeIndex]![seasonId] = seasonName;
          
          // Update current season IDs to latest
          if (programId == vexIQProgramId) {
            if (seasonId > currentVexIQSeasonId) {
              currentVexIQSeasonId = seasonId;
            }
          } else if (programId == vrcProgramId) {
            if (seasonId > currentVRCSeasonId) {
              currentVRCSeasonId = seasonId;
            }
          } else if (programId == vexuProgramId) {
            if (seasonId > currentVEXUSeasonId) {
              currentVEXUSeasonId = seasonId;
            }
          }
        }
        
        print('Successfully loaded ${seasonIdMap[2]!.length} VEX IQ seasons');
        print('Current VEX IQ season ID: $currentVexIQSeasonId');
        print('=== End Season ID Map Generation ===');
      }
    } catch (e) {
      print('Error generating season ID map: $e');
    }
  }
  
  // Get selected program ID (matches Swift selected_program_id function)
  static int getSelectedProgramId() {
    return vexIQProgramId; // Always VEX IQ for this app
  }
  
  // Get current season ID for selected program (matches Swift logic)
  static int getSelectedSeasonId() {
    return currentVexIQSeasonId;
  }
  
  // Team search parameters (matches Swift Team.fetch_info implementation)
  static Map<String, dynamic> getTeamSearchParams({
    String? teamNumber,
    int? teamId,
    int? seasonId,
  }) {
    // Matches Swift implementation exactly
    if (teamId != null && teamId != 0) {
      return {
        'id': teamId,
        'program': getSelectedProgramId(),
      };
    } else if (teamNumber != null && teamNumber.isNotEmpty) {
      // Use array format for number parameter like the working API call
      return {
        'number[]': teamNumber,
        'program': [vrcProgramId, vexuProgramId, vexIQProgramId],
      };
    } else {
      return {
        'program': getSelectedProgramId(),
      };
    }
  }
  
  // Event search parameters (simplified for new multi-strategy approach)
  static Map<String, dynamic> getEventSearchParams({
    String? query,
    int? seasonId, 
    int? levelClass,
    List<String>? levels,
    int page = 1,
  }) {
    final selectedSeasonId = seasonId ?? getSelectedSeasonId();
    print('🔍 Building event search params with season ID: $selectedSeasonId (passed: $seasonId, default: ${getSelectedSeasonId()})');
    
    final params = <String, dynamic>{
      'page': page,
      'per_page': defaultPageSize,
      'program': getSelectedProgramId(),
      'season': selectedSeasonId,
    };
    
    if (query != null && query.isNotEmpty) {
      params['name'] = query.trim();
    }
    
    if (levelClass != null && levelClass != 0) {
      params['level_class_id'] = levelClass;
    }
    
    if (levels != null && levels.isNotEmpty) {
      params['level[]'] = levels;
    }
    
    print('🔍 Final event search params: $params');
    return params;
  }
  
  // Team events parameters (matches Swift fetch_events implementation)
  static Map<String, dynamic> getTeamEventsParams({
    required int teamId,
    int? seasonId,
  }) {
    return {
      'team': teamId,
      'season': seasonId ?? getSelectedSeasonId(),
    };
  }
  
  // Team awards parameters (matches Swift fetch_awards implementation)  
  static Map<String, dynamic> getTeamAwardsParams({
    required int teamId,
    int? seasonId,
  }) {
    return {
      'season': seasonId ?? getSelectedSeasonId(),
    };
  }
  
  // Team rankings parameters (matches Swift average_ranking implementation)
  static Map<String, dynamic> getTeamRankingsParams({
    required int teamId,
    int? seasonId,
  }) {
    return {
      'season': seasonId ?? getSelectedSeasonId(),
    };
  }
  
  // Skills rankings parameters (matches Swift world skills logic)
  static Map<String, dynamic> getSkillsParams({
    int? seasonId,
    int page = 1,
  }) {
    return {
      'page': page,
      'per_page': defaultPageSize,
      'program': getSelectedProgramId(),
      'season': seasonId ?? getSelectedSeasonId(),
    };
  }
  
  // Error handling
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String apiErrorMessage = 'API error. Please try again later.';
  static const String unauthorizedMessage = 'Unauthorized. Please check your API key.';
  static const String rateLimitMessage = 'Rate limit exceeded. Please wait before trying again.';
  static const String timeoutMessage = 'Request timeout. Please try again.';
  static const String noDataMessage = 'No data found for this request.';
  
  // Utility methods
  static bool get isApiKeyConfigured => robotEventsApiKey != 'YOUR_NEW_API_KEY_HERE' && robotEventsApiKey.isNotEmpty;
  
  // Get season display name  
  static String getSeasonDisplayName(int seasonId) {
    // Check available seasons first for known display names
    for (final entry in availableSeasons.entries) {
      if (entry.value['vexiq'] == seasonId) {
        return entry.key;
      }
    }
    
    // Fallback to dynamic mapping if available
    if (seasonIdMap[2]!.containsKey(seasonId)) {
      String seasonName = seasonIdMap[2]![seasonId]!;
      // Format season name (remove "VEX IQ Robotics Competition" prefix and clean up)
      seasonName = seasonName.replaceAll(RegExp(r'^VEX IQ Robotics Competition\s*'), '');
      seasonName = seasonName.replaceAll(RegExp(r'^VIQRC\s*'), '');
      return seasonName;
    }
    
    return 'Season $seasonId';
  }
  
  // Available grade levels for VEX IQ
  static const List<String> availableGradeLevels = [
    'Elementary School',
    'Middle School',
  ];
  
  // Available event levels for filtering (ordered as requested: All -> Regional Championships -> National Championships -> Signature Events -> Worlds)
  static const List<String> availableEventLevels = [
    'Other',           // All (catch-all for other event types)
    'State',           // Regional Championships (renamed from "State")
    'National',        // National Championships
    'Signature',       // Signature Events
    'World',           // Worlds
  ];
} 