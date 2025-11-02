import 'dart:convert';
import 'package:flutter/services.dart';

/// Service to load and query special team designations
class SpecialTeamsService {
  static SpecialTeamsService? _instance;
  static SpecialTeamsService get instance => _instance ??= SpecialTeamsService._();
  
  SpecialTeamsService._();
  
  Map<String, dynamic>? _specialTeamsData;
  bool _isLoaded = false;
  
  /// Load special teams data from assets
  Future<void> load() async {
    if (_isLoaded) return;
    
    try {
      final String jsonString = await rootBundle.loadString('assets/special_teams.json');
      _specialTeamsData = json.decode(jsonString) as Map<String, dynamic>;
      _isLoaded = true;
      print('✅ Loaded special teams data');
      
      // Debug: Print all teams
      final tierNames = ['cappedPinsAlliance', 'robostem', 'highlighted'];
      for (final tierName in tierNames) {
        final tierData = _specialTeamsData![tierName] as Map<String, dynamic>?;
        final teams = tierData?['teams'] as List<dynamic>?;
        print('⭐ Tier $tierName: ${teams?.length ?? 0} teams - $teams');
      }
    } catch (e) {
      print('❌ Error loading special teams: $e');
      _specialTeamsData = null;
    }
  }
  
  /// Get the tier/type for a team number
  String? getTeamTier(String teamNumber) {
    if (!_isLoaded || _specialTeamsData == null) {
      print('❌ SpecialTeamsService: Not loaded or no data');
      return null;
    }
    
    final tierNames = ['cappedPinsAlliance', 'robostem', 'highlighted'];
    final lowerTeamNumber = teamNumber.toLowerCase();
    
    for (final tierName in tierNames) {
      final tierData = _specialTeamsData![tierName] as Map<String, dynamic>?;
      final teams = tierData?['teams'] as List<dynamic>?;
      if (teams != null) {
        for (final team in teams) {
          final lowerTeam = team.toString().toLowerCase();
          if (lowerTeam == lowerTeamNumber) {
            print('✅ Found special team: $teamNumber -> $tierName');
            return tierName;
          }
        }
      }
    }
    
    print('❌ No special tier found for team: $teamNumber');
    return null;
  }
  
  /// Get the display name for a tier
  String getTierDisplayName(String tierName) {
    switch (tierName) {
      case 'cappedPinsAlliance':
        return 'Capped Pins Alliance';
      case 'robostem':
        return 'RoboStem';
      case 'highlighted':
        return 'Highlighted';
      default:
        return tierName;
    }
  }
  
  /// Get the description for a tier
  String? getTierDescription(String tierName) {
    if (!_isLoaded || _specialTeamsData == null) return null;
    
    final tierData = _specialTeamsData![tierName] as Map<String, dynamic>?;
    return tierData?['description'] as String?;
  }
  
  /// Get the color for a tier
  String? getTierColor(String tierName) {
    if (!_isLoaded || _specialTeamsData == null) return null;
    
    final tierData = _specialTeamsData![tierName] as Map<String, dynamic>?;
    return tierData?['color'] as String?;
  }
  
  /// Get the accent color for a tier
  String? getTierAccentColor(String tierName) {
    if (!_isLoaded || _specialTeamsData == null) return null;
    
    final tierData = _specialTeamsData![tierName] as Map<String, dynamic>?;
    return tierData?['accentColor'] as String?;
  }
  
  /// Convert hex color string to Color
  static int _hexToInt(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Add alpha if not present
    }
    return int.parse(hex, radix: 16);
  }
  
  /// Get the Color object for a tier
  int? getTierColorInt(String tierName) {
    final colorHex = getTierColor(tierName);
    if (colorHex == null) return null;
    return _hexToInt(colorHex);
  }
  
  /// Get the accent Color object for a tier
  int? getTierAccentColorInt(String tierName) {
    final colorHex = getTierAccentColor(tierName);
    if (colorHex == null) return null;
    return _hexToInt(colorHex);
  }
}

