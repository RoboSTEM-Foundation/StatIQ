import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TeamSearchService {
  static const String _searchIndexKey = 'team_search_index';
  static const String _teamDataKey = 'cached_team_list';
  
  // Search indexes for fast lookups
  static Map<String, List<int>> _numberIndex = {};
  static Map<String, List<int>> _nameIndex = {};
  static Map<String, List<int>> _organizationIndex = {};
  static Map<String, List<int>> _locationIndex = {};
  static List<Map<String, dynamic>> _allTeams = [];
  
  /// Initialize search indexes from cached team data
  static Future<void> initializeSearchIndexes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTeamsString = prefs.getString(_teamDataKey);
    
    if (cachedTeamsString != null) {
      final Map<String, dynamic> data = json.decode(cachedTeamsString);
      _allTeams = List<Map<String, dynamic>>.from(data['teams'] ?? []);
      _buildSearchIndexes();
      print('🔍 Search indexes built for ${_allTeams.length} teams');
    }
  }
  
  /// Build optimized search indexes
  static void _buildSearchIndexes() {
    _numberIndex.clear();
    _nameIndex.clear();
    _organizationIndex.clear();
    _locationIndex.clear();
    
    for (int i = 0; i < _allTeams.length; i++) {
      final team = _allTeams[i];
      
      // Team number index (most important for fast searches)
      final teamNumber = (team['number'] ?? '').toString().toLowerCase();
      if (teamNumber.isNotEmpty) {
        // Add full number
        _addToIndex(_numberIndex, teamNumber, i);
        
        // Add prefixes for fast partial matching
        for (int j = 1; j <= teamNumber.length; j++) {
          _addToIndex(_numberIndex, teamNumber.substring(0, j), i);
        }
      }
      
      // Team name index
      final teamName = (team['name'] ?? '').toString().toLowerCase();
      if (teamName.isNotEmpty) {
        _addToIndex(_nameIndex, teamName, i);
        // Add word prefixes
        final words = teamName.split(' ');
        for (final word in words) {
          if (word.isNotEmpty) {
            for (int j = 1; j <= word.length; j++) {
              _addToIndex(_nameIndex, word.substring(0, j), i);
            }
          }
        }
      }
      
      // Organization index
      final organization = (team['organization'] ?? '').toString().toLowerCase();
      if (organization.isNotEmpty) {
        _addToIndex(_organizationIndex, organization, i);
        final words = organization.split(' ');
        for (final word in words) {
          if (word.isNotEmpty) {
            for (int j = 1; j <= word.length; j++) {
              _addToIndex(_organizationIndex, word.substring(0, j), i);
            }
          }
        }
      }
      
      // Location index
      final city = (team['city'] ?? '').toString().toLowerCase();
      final region = (team['region'] ?? '').toString().toLowerCase();
      final location = '$city $region'.trim();
      if (location.isNotEmpty) {
        _addToIndex(_locationIndex, location, i);
        final words = location.split(' ');
        for (final word in words) {
          if (word.isNotEmpty) {
            for (int j = 1; j <= word.length; j++) {
              _addToIndex(_locationIndex, word.substring(0, j), i);
            }
          }
        }
      }
    }
    
    // Cache the indexes
    _cacheSearchIndexes();
  }
  
  /// Add entry to search index
  static void _addToIndex(Map<String, List<int>> index, String key, int teamIndex) {
    if (key.isEmpty) return;
    
    if (index.containsKey(key)) {
      if (!index[key]!.contains(teamIndex)) {
        index[key]!.add(teamIndex);
      }
    } else {
      index[key] = [teamIndex];
    }
  }
  
  /// Cache search indexes for faster startup
  static Future<void> _cacheSearchIndexes() async {
    final prefs = await SharedPreferences.getInstance();
    final indexData = {
      'numberIndex': _numberIndex,
      'nameIndex': _nameIndex,
      'organizationIndex': _organizationIndex,
      'locationIndex': _locationIndex,
      'teamCount': _allTeams.length,
    };
    await prefs.setString(_searchIndexKey, json.encode(indexData));
  }
  
  /// Load cached search indexes
  static Future<bool> _loadCachedIndexes() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedIndexString = prefs.getString(_searchIndexKey);
    
    if (cachedIndexString != null) {
      try {
        final indexData = json.decode(cachedIndexString);
        _numberIndex = Map<String, List<int>>.from(
          (indexData['numberIndex'] as Map).map((k, v) => MapEntry(k.toString(), List<int>.from(v)))
        );
        _nameIndex = Map<String, List<int>>.from(
          (indexData['nameIndex'] as Map).map((k, v) => MapEntry(k.toString(), List<int>.from(v)))
        );
        _organizationIndex = Map<String, List<int>>.from(
          (indexData['organizationIndex'] as Map).map((k, v) => MapEntry(k.toString(), List<int>.from(v)))
        );
        _locationIndex = Map<String, List<int>>.from(
          (indexData['locationIndex'] as Map).map((k, v) => MapEntry(k.toString(), List<int>.from(v)))
        );
        
        print('🔍 Loaded cached search indexes');
        return true;
      } catch (e) {
        print('❌ Error loading cached indexes: $e');
        return false;
      }
    }
    return false;
  }
  
  /// Fast search with multiple strategies
  static List<Map<String, dynamic>> searchTeams(String query, {int limit = 100}) {
    if (query.isEmpty) {
      return _allTeams.take(limit).toList();
    }
    
    final lowerQuery = query.toLowerCase().trim();
    final Set<int> resultIndices = {};
    
    // Strategy 1: Exact team number match (highest priority)
    if (_numberIndex.containsKey(lowerQuery)) {
      resultIndices.addAll(_numberIndex[lowerQuery]!);
    }
    
    // Strategy 2: Team number prefix matches
    final numberPrefixes = _numberIndex.keys.where((key) => key.startsWith(lowerQuery)).toList();
    for (final prefix in numberPrefixes) {
      resultIndices.addAll(_numberIndex[prefix]!);
    }
    
    // Strategy 3: Team name matches
    final nameMatches = _nameIndex.keys.where((key) => key.contains(lowerQuery)).toList();
    for (final match in nameMatches) {
      resultIndices.addAll(_nameIndex[match]!);
    }
    
    // Strategy 4: Organization matches
    final orgMatches = _organizationIndex.keys.where((key) => key.contains(lowerQuery)).toList();
    for (final match in orgMatches) {
      resultIndices.addAll(_organizationIndex[match]!);
    }
    
    // Strategy 5: Location matches
    final locationMatches = _locationIndex.keys.where((key) => key.contains(lowerQuery)).toList();
    for (final match in locationMatches) {
      resultIndices.addAll(_locationIndex[match]!);
    }
    
    // Convert indices to team data and sort by relevance
    final results = resultIndices.map((index) => _allTeams[index]).toList();
    return _sortByRelevance(results, lowerQuery).take(limit).toList();
  }
  
  /// Sort results by relevance (exact matches first, then prefix matches, then contains)
  static List<Map<String, dynamic>> _sortByRelevance(List<Map<String, dynamic>> teams, String query) {
    return teams..sort((a, b) {
      final aNumber = (a['number'] ?? '').toString().toLowerCase();
      final bNumber = (b['number'] ?? '').toString().toLowerCase();
      
      // Exact match gets highest priority
      if (aNumber == query && bNumber != query) return -1;
      if (bNumber == query && aNumber != query) return 1;
      
      // Prefix match gets second priority
      final aStartsWith = aNumber.startsWith(query);
      final bStartsWith = bNumber.startsWith(query);
      if (aStartsWith && !bStartsWith) return -1;
      if (bStartsWith && !aStartsWith) return 1;
      
      // Shorter team numbers get priority (more specific)
      if (aNumber.length != bNumber.length) {
        return aNumber.length.compareTo(bNumber.length);
      }
      
      // Alphabetical order as tiebreaker
      return aNumber.compareTo(bNumber);
    });
  }
  
  /// Get team by exact number (fastest lookup)
  static Map<String, dynamic>? getTeamByNumber(String teamNumber) {
    final lowerNumber = teamNumber.toLowerCase();
    if (_numberIndex.containsKey(lowerNumber)) {
      final indices = _numberIndex[lowerNumber]!;
      if (indices.isNotEmpty) {
        return _allTeams[indices.first];
      }
    }
    return null;
  }
  
  /// Get search suggestions for autocomplete
  static List<String> getSearchSuggestions(String query, {int limit = 10}) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    final Set<String> suggestions = {};
    
    // Get team number suggestions
    final numberSuggestions = _numberIndex.keys
        .where((key) => key.startsWith(lowerQuery))
        .take(limit)
        .toList();
    
    for (final suggestion in numberSuggestions) {
      final indices = _numberIndex[suggestion]!;
      if (indices.isNotEmpty) {
        final team = _allTeams[indices.first];
        suggestions.add(team['number']?.toString() ?? '');
      }
    }
    
    return suggestions.take(limit).toList();
  }
  
  /// Get search statistics
  static Map<String, dynamic> getSearchStats() {
    return {
      'totalTeams': _allTeams.length,
      'numberIndexSize': _numberIndex.length,
      'nameIndexSize': _nameIndex.length,
      'organizationIndexSize': _organizationIndex.length,
      'locationIndexSize': _locationIndex.length,
    };
  }
  
  /// Clear all search data
  static Future<void> clearSearchData() async {
    _numberIndex.clear();
    _nameIndex.clear();
    _organizationIndex.clear();
    _locationIndex.clear();
    _allTeams.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchIndexKey);
    await prefs.remove(_teamDataKey);
  }
}
