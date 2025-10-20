import 'package:stat_iq/data/team_master_list.dart';

class TeamMasterListService {
  static TeamMasterListService? _instance;
  static TeamMasterListService get instance => _instance ??= TeamMasterListService._();
  
  TeamMasterListService._();

  /// Get team information by team number
  Map<String, dynamic>? getTeamInfo(String teamNumber) {
    return TeamMasterList.teamLookup[teamNumber];
  }

  /// Check if a team exists in the master list
  bool teamExists(String teamNumber) {
    return TeamMasterList.teamLookup.containsKey(teamNumber);
  }

  /// Get all team numbers
  List<String> getAllTeamNumbers() {
    return TeamMasterList.teamLookup.keys.toList();
  }

  /// Search teams by name (case-insensitive)
  List<Map<String, dynamic>> searchTeamsByName(String query) {
    if (query.isEmpty) return [];
    
    final lowercaseQuery = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    
    TeamMasterList.teamLookup.forEach((number, teamData) {
      final teamName = (teamData['name'] as String? ?? '').toLowerCase();
      final organization = (teamData['organization'] as String? ?? '').toLowerCase();
      
      if (teamName.contains(lowercaseQuery) || 
          organization.contains(lowercaseQuery) ||
          number.toLowerCase().contains(lowercaseQuery)) {
        results.add({
          'number': number,
          ...teamData,
        });
      }
    });
    
    // Sort by team number
    results.sort((a, b) {
      final numA = int.tryParse(a['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });
    
    return results;
  }

  /// Search teams by location
  List<Map<String, dynamic>> searchTeamsByLocation(String query) {
    if (query.isEmpty) return [];
    
    final lowercaseQuery = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    
    TeamMasterList.teamLookup.forEach((number, teamData) {
      final city = (teamData['city'] as String? ?? '').toLowerCase();
      final region = (teamData['region'] as String? ?? '').toLowerCase();
      final country = (teamData['country'] as String? ?? '').toLowerCase();
      final location = (teamData['location'] as String? ?? '').toLowerCase();
      
      if (city.contains(lowercaseQuery) || 
          region.contains(lowercaseQuery) ||
          country.contains(lowercaseQuery) ||
          location.contains(lowercaseQuery)) {
        results.add({
          'number': number,
          ...teamData,
        });
      }
    });
    
    // Sort by team number
    results.sort((a, b) {
      final numA = int.tryParse(a['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });
    
    return results;
  }

  /// Get teams by grade level
  List<Map<String, dynamic>> getTeamsByGrade(String grade) {
    final results = <Map<String, dynamic>>[];
    
    TeamMasterList.teamLookup.forEach((number, teamData) {
      if (teamData['grade'] == grade) {
        results.add({
          'number': number,
          ...teamData,
        });
      }
    });
    
    // Sort by team number
    results.sort((a, b) {
      final numA = int.tryParse(a['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });
    
    return results;
  }

  /// Get teams by organization
  List<Map<String, dynamic>> getTeamsByOrganization(String organization) {
    final results = <Map<String, dynamic>>[];
    
    TeamMasterList.teamLookup.forEach((number, teamData) {
      if ((teamData['organization'] as String? ?? '').toLowerCase().contains(organization.toLowerCase())) {
        results.add({
          'number': number,
          ...teamData,
        });
      }
    });
    
    // Sort by team number
    results.sort((a, b) {
      final numA = int.tryParse(a['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });
    
    return results;
  }

  /// Get all teams as a list
  List<Map<String, dynamic>> getAllTeams() {
    final results = <Map<String, dynamic>>[];
    
    TeamMasterList.teamLookup.forEach((number, teamData) {
      results.add({
        'number': number,
        ...teamData,
      });
    });
    
    // Sort by team number
    results.sort((a, b) {
      final numA = int.tryParse(a['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });
    
    return results;
  }

  /// Get teams in a number range
  List<Map<String, dynamic>> getTeamsInRange(int startNumber, int endNumber) {
    final results = <Map<String, dynamic>>[];
    
    TeamMasterList.teamLookup.forEach((number, teamData) {
      final teamNum = int.tryParse(number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (teamNum >= startNumber && teamNum <= endNumber) {
        results.add({
          'number': number,
          ...teamData,
        });
      }
    });
    
    // Sort by team number
    results.sort((a, b) {
      final numA = int.tryParse(a['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b['number'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });
    
    return results;
  }

  /// Get metadata about the team list
  Map<String, dynamic> getMetadata() {
    return TeamMasterList.metadata;
  }

  /// Get total number of teams
  int getTotalTeams() {
    return TeamMasterList.totalTeams;
  }

  /// Get last update timestamp
  String getLastUpdated() {
    return TeamMasterList.lastUpdated;
  }

  /// Check if the data is recent (within last 7 days)
  bool isDataRecent() {
    try {
      final lastUpdated = DateTime.parse(TeamMasterList.lastUpdated);
      final now = DateTime.now();
      final difference = now.difference(lastUpdated);
      return difference.inDays <= 7;
    } catch (e) {
      return false;
    }
  }

  /// Get data age in days
  int getDataAgeInDays() {
    try {
      final lastUpdated = DateTime.parse(TeamMasterList.lastUpdated);
      final now = DateTime.now();
      final difference = now.difference(lastUpdated);
      return difference.inDays;
    } catch (e) {
      return -1;
    }
  }

  /// Get statistics about the team list
  Map<String, dynamic> getStatistics() {
    final allTeams = getAllTeams();
    final gradeCounts = <String, int>{};
    final countryCounts = <String, int>{};
    final regionCounts = <String, int>{};
    
    for (final team in allTeams) {
      final grade = team['grade'] as String? ?? 'Unknown';
      final country = team['country'] as String? ?? 'Unknown';
      final region = team['region'] as String? ?? 'Unknown';
      
      gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
      countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      regionCounts[region] = (regionCounts[region] ?? 0) + 1;
    }
    
    return {
      'totalTeams': allTeams.length,
      'gradeDistribution': gradeCounts,
      'countryDistribution': countryCounts,
      'regionDistribution': regionCounts,
      'lastUpdated': TeamMasterList.lastUpdated,
      'dataAgeInDays': getDataAgeInDays(),
    };
  }
}
