import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Highly optimized search for 26,000+ teams
/// Uses pre-built indexes and efficient data structures
class OptimizedTeamSearch {
  static const String _teamListKey = 'cached_team_list';
  static const String _indexKey = 'team_search_index';
  
  // Core data
  static List<Map<String, dynamic>> _allTeams = [];
  static bool _isInitialized = false;
  static bool _indexesBuilt = false;
  static double _indexingProgress = 0.0;
  static String _indexingStatus = 'Preparing...';
  
  // Optimized indexes for fast lookup
  static Map<String, List<int>> _numberIndex = {}; // team number -> list of indices
  static Map<String, List<int>> _nameIndex = {};   // team name -> list of indices
  static Map<String, List<int>> _orgIndex = {};    // organization -> list of indices
  static Map<String, List<int>> _cityIndex = {};   // city -> list of indices
  
  // Pagination
  static const int _pageSize = 50;
  static const int _maxResults = 200; // Limit total results to prevent lag
  
  /// Initialize with optimized indexing
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTeamsString = prefs.getString(_teamListKey);
      
      print('🔍 Checking for cached team data...');
      print('📊 Cached data length: ${cachedTeamsString?.length ?? 0}');
      
      if (cachedTeamsString != null) {
        print('📥 Parsing cached team data...');
        final Map<String, dynamic> data = json.decode(cachedTeamsString);
        _allTeams = List<Map<String, dynamic>>.from(data['teams'] ?? []);
        
        print('📊 Parsed ${_allTeams.length} teams from cache');
        
        // Build indexes in background to avoid blocking UI
        await _buildIndexesAsync();
        
        _isInitialized = true;
        print('🚀 OptimizedTeamSearch initialized with ${_allTeams.length} teams');
      } else {
        _allTeams = [];
        print('⚠️ OptimizedTeamSearch: No cached team list found');
      }
    } catch (e) {
      print('❌ Error initializing optimized search: $e');
      _allTeams = [];
    }
  }
  
  /// Build search indexes asynchronously
  static Future<void> _buildIndexesAsync() async {
    try {
      print('🔨 Building search indexes...');
      print('📊 Total teams to index: ${_allTeams.length}');
      final stopwatch = Stopwatch()..start();
      
      _indexingProgress = 0.0;
      _indexingStatus = 'Clearing old indexes...';
      
      _numberIndex.clear();
      _nameIndex.clear();
      _orgIndex.clear();
      _cityIndex.clear();
      
      if (_allTeams.isEmpty) {
        _indexingStatus = 'No teams to index';
        _indexingProgress = 1.0;
        _indexesBuilt = true;
        print('⚠️ No teams available for indexing');
        return;
      }
      
      _indexingStatus = 'Indexing team data...';
      
      // Process in batches to yield control
      const batchSize = 1000;
      for (int i = 0; i < _allTeams.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, _allTeams.length);
        
        for (int j = i; j < end; j++) {
          try {
            final team = _allTeams[j];
            final teamNumber = (team['number'] ?? '').toString().toLowerCase();
            final teamName = (team['name'] ?? '').toString().toLowerCase();
            final organization = (team['organization'] ?? '').toString().toLowerCase();
            
            // Handle location - it's a string, not a nested object
            String city = '';
            if (team['city'] != null) {
              city = team['city'].toString().toLowerCase();
            } else if (team['location'] != null) {
              // Extract city from location string (e.g., "Vancouver, British Columbia, Canada" -> "Vancouver")
              final location = team['location'].toString();
              final parts = location.split(',');
              if (parts.isNotEmpty) {
                city = parts[0].trim().toLowerCase();
              }
            }
          
            // Index team number (most important)
            if (teamNumber.isNotEmpty) {
              _numberIndex.putIfAbsent(teamNumber, () => []).add(j);
              
              // Also index partial numbers (e.g., "2" for "2A", "14" for "14G")
              final numberOnly = teamNumber.replaceAll(RegExp(r'[^0-9]'), '');
              if (numberOnly.isNotEmpty && numberOnly != teamNumber) {
                _numberIndex.putIfAbsent(numberOnly, () => []).add(j);
              }
            }
            
            // Index team name
            if (teamName.isNotEmpty) {
              _nameIndex.putIfAbsent(teamName, () => []).add(j);
            }
            
            // Index organization
            if (organization.isNotEmpty) {
              _orgIndex.putIfAbsent(organization, () => []).add(j);
            }
            
            // Index city
            if (city.isNotEmpty) {
              _cityIndex.putIfAbsent(city, () => []).add(j);
            }
          } catch (e) {
            print('❌ Error indexing team at index $j: $e');
            print('📊 Team data: ${_allTeams[j].toString()}');
            continue; // Skip this team and continue with the next one
          }
        }
        
        // Update progress
        if (_allTeams.isNotEmpty) {
          _indexingProgress = (i + batchSize) / _allTeams.length;
          _indexingStatus = 'Indexing teams ${i + batchSize}/${_allTeams.length}...';
        } else {
          _indexingProgress = 0.0;
          _indexingStatus = 'No teams to index';
        }
        
        // Yield control every batch
        if (i + batchSize < _allTeams.length) {
          await Future.delayed(Duration.zero);
        }
      }
      
      _indexingStatus = 'Finalizing indexes...';
      _indexingProgress = 1.0;
      
      stopwatch.stop();
      _indexesBuilt = true;
      _indexingStatus = 'Ready!';
      
      print('✅ Indexes built in ${stopwatch.elapsedMilliseconds}ms');
      print('📊 Index stats: ${_numberIndex.length} numbers, ${_nameIndex.length} names, ${_orgIndex.length} orgs, ${_cityIndex.length} cities');
    } catch (e) {
      print('❌ Error building indexes: $e');
      _indexingStatus = 'Indexing failed: $e';
      _indexingProgress = 0.0;
      _indexesBuilt = false;
      // Don't rethrow - allow the app to continue with basic search
    }
  }
  
  /// Get first N teams (for default display)
  static List<Map<String, dynamic>> getFirstTeams(int count) {
    if (!_isInitialized || _allTeams.isEmpty) return [];
    return _allTeams.take(count).toList();
  }
  
  /// Ultra-fast search using pre-built indexes
  static List<Map<String, dynamic>> search(String query, {int page = 0}) {
    if (!_isInitialized || _allTeams.isEmpty || !_indexesBuilt) {
      return page == 0 ? getFirstTeams(20) : [];
    }
    
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getFirstTeams(20);
    }
    
    final lowerQuery = trimmedQuery.toLowerCase();
    final Set<int> resultIndices = {};
    
    // 1. Exact team number match (highest priority)
    if (_numberIndex.containsKey(lowerQuery)) {
      resultIndices.addAll(_numberIndex[lowerQuery]!);
    }
    
    // 2. Team number starts with query
    for (final entry in _numberIndex.entries) {
      if (entry.key.startsWith(lowerQuery)) {
        resultIndices.addAll(entry.value);
        if (resultIndices.length >= _maxResults) break;
      }
    }
    
    // 3. If still not enough results, search names and orgs
    if (resultIndices.length < 50) {
      for (final entry in _nameIndex.entries) {
        if (entry.key.contains(lowerQuery)) {
          resultIndices.addAll(entry.value);
          if (resultIndices.length >= _maxResults) break;
        }
      }
      
      for (final entry in _orgIndex.entries) {
        if (entry.key.contains(lowerQuery)) {
          resultIndices.addAll(entry.value);
          if (resultIndices.length >= _maxResults) break;
        }
      }
    }
    
    // Convert indices to teams and sort by relevance
    final results = resultIndices
        .map((index) => _allTeams[index])
        .toList();
    
    // Sort by relevance (exact matches first, then by team number)
    results.sort((a, b) {
      final aNumber = (a['number'] ?? '').toString().toLowerCase();
      final bNumber = (b['number'] ?? '').toString().toLowerCase();
      
      // Exact match gets priority
      if (aNumber == lowerQuery && bNumber != lowerQuery) return -1;
      if (bNumber == lowerQuery && aNumber != lowerQuery) return 1;
      
      // Then by starts with
      if (aNumber.startsWith(lowerQuery) && !bNumber.startsWith(lowerQuery)) return -1;
      if (bNumber.startsWith(lowerQuery) && !aNumber.startsWith(lowerQuery)) return 1;
      
      // Finally by alphabetical
      return aNumber.compareTo(bNumber);
    });
    
    // Apply pagination
    final startIndex = page * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, results.length);
    
    return results.sublist(startIndex, endIndex);
  }
  
  /// Check if search is ready
  static bool isReady() => _isInitialized && _allTeams.isNotEmpty && _indexesBuilt;
  
  /// Get total team count
  static int getTeamCount() => _allTeams.length;
  
  /// Get indexing progress (0.0 to 1.0)
  static double getIndexingProgress() => _indexingProgress;
  
  /// Get indexing status message
  static String getIndexingStatus() => _indexingStatus;
  
  /// Get search statistics
  static Map<String, dynamic> getStats() {
    return {
      'totalTeams': _allTeams.length,
      'indexesBuilt': _numberIndex.isNotEmpty,
      'numberIndexSize': _numberIndex.length,
      'nameIndexSize': _nameIndex.length,
      'orgIndexSize': _orgIndex.length,
      'cityIndexSize': _cityIndex.length,
    };
  }
  
  /// Clear all cached data
  static Future<void> clearCache() async {
    print('🧹 Clearing OptimizedTeamSearch cache...');
    
    // Clear all data
    _allTeams.clear();
    _numberIndex.clear();
    _nameIndex.clear();
    _orgIndex.clear();
    _cityIndex.clear();
    
    // Reset state
    _isInitialized = false;
    _indexesBuilt = false;
    _indexingProgress = 0.0;
    _indexingStatus = 'Not started';
    
    print('🧹 OptimizedTeamSearch cache cleared');
  }
}
