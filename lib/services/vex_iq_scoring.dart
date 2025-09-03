import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:flutter/material.dart';

class VEXIQScoring {
  // statIQ Score™ - Custom scoring system for VEX IQ teams
  // Updated for Mix and Match (2025-2026 season)
  
  static Future<String> calculateVEXIQScore({
    required Team team,
    List<dynamic>? worldSkillsData,
    List<dynamic>? eventsData,
    List<dynamic>? awardsData,
    List<dynamic>? rankingsData,
    int? seasonId,
  }) async {
    print('=== statIQ Score Calculation Debug for ${team.number} ===');
    
    double totalScore = 0.0;
    double maxScore = 100.0;
    
    // Parse world skills data from API response or fetch from VexDB
    Map<String, dynamic> worldSkills = await _parseWorldSkillsWithFallback(
      worldSkillsData, 
      team.number, 
      seasonId,
    );
    
    final hasSkillsData = !(worldSkills['estimated'] == true);
    
    if (hasSkillsData) {
      // Standard scoring with skills data
      // 1. World Skills Ranking (30 points)
      final worldSkillsScore = _calculateWorldSkillsRankingScore(worldSkills);
      totalScore += worldSkillsScore;
      print('World Skills Ranking Score: ${worldSkillsScore.toStringAsFixed(2)} / 30.0');
      
      // 2. Skills Score Quality (25 points) + Balance Bonus (5 points)
      final skillsScores = await _calculateSkillsScoreQuality(worldSkills, seasonId: seasonId);
      totalScore += skillsScores['quality']!;
      totalScore += skillsScores['balance']!;
      if (skillsScores['balance']! > 0) {
        maxScore += 5.0; // Balance bonus increases max score
      }
      print('Skills Score Quality: ${skillsScores['quality']!.toStringAsFixed(2)} / 25.0');
      print('Skills Balance Bonus: ${skillsScores['balance']!.toStringAsFixed(2)} / 5.0');
      
      // 3. Competition Performance (20 points)
      final competitionScore = _calculateCompetitionPerformance(rankingsData);
      totalScore += competitionScore;
      print('Competition Performance: ${competitionScore.toStringAsFixed(2)} / 20.0');
      
      // 4. Award Excellence (20 points)
      final awardScore = _calculateAwardExcellence(awardsData);
      totalScore += awardScore;
      print('Award Excellence: ${awardScore.toStringAsFixed(2)} / 20.0');
    } else {
      // Enhanced scoring without skills data (redistribute weights)
      print('No skills data - using enhanced competition-based scoring');
      
      // 1. Competition Performance (40 points - doubled weight)
      final competitionScore = _calculateCompetitionPerformance(rankingsData) * 2.0;
      totalScore += competitionScore;
      print('Enhanced Competition Performance: ${competitionScore.toStringAsFixed(2)} / 40.0');
      
      // 2. Award Excellence (30 points - increased weight)
      final awardScore = _calculateAwardExcellence(awardsData) * 1.5;
      totalScore += awardScore;
      print('Enhanced Award Excellence: ${awardScore.toStringAsFixed(2)} / 30.0');
      
      // 3. Event Participation Bonus (15 points)
      final participationScore = _calculateEventParticipation(eventsData);
      totalScore += participationScore;
      print('Event Participation Score: ${participationScore.toStringAsFixed(2)} / 15.0');
      
      // 4. Consistency Bonus (15 points)
      final consistencyScore = _calculateConsistencyBonus(rankingsData);
      totalScore += consistencyScore;
      print('Consistency Bonus: ${consistencyScore.toStringAsFixed(2)} / 15.0');
    }
    
    // Calculate final percentage
    final percentage = (totalScore / maxScore) * 100.0;
    
    print('Total Score: ${totalScore.toStringAsFixed(2)} / ${maxScore.toStringAsFixed(2)}');
    print('Percentage: ${percentage.toStringAsFixed(2)}%');
    print('Performance Tier: ${getPerformanceTier(percentage, team.grade)}');
    print('=== End statIQ Score Calculation ===');
    
    return percentage.toStringAsFixed(1);
  }
  
    // Parse world skills data with enhanced fallback
  static Future<Map<String, dynamic>> _parseWorldSkillsWithFallback(
    List<dynamic>? worldSkillsData,
    String teamNumber,
    int? seasonId,
  ) async {
    // Try RobotEvents API data
    if (worldSkillsData != null && worldSkillsData.isNotEmpty) {
      print('Using RobotEvents skills data');
      return _parseWorldSkills(worldSkillsData);
    }
    
    // Skills data unavailable - estimate from competition performance
    print('No skills data available - using competition performance estimate');
    return {
      'ranking': 0,
      'combined': 0,
      'driver': 0,
      'programming': 0,
      'totalTeams': 0,
      'estimated': true, // Flag to indicate this is estimated
    };
  }
    
  // Parse world skills data from various possible API responses
  static Map<String, dynamic> _parseWorldSkills(List<dynamic>? worldSkillsData) {
    if (worldSkillsData == null || worldSkillsData.isEmpty) {
      print('No skills data provided to parse');
      return {
        'ranking': 0,
        'combined': 0,
        'driver': 0,
        'programming': 0,
        'totalTeams': 0,
      };
    }
    
    print('Parsing skills data with ${worldSkillsData.length} records');
    
    // For skills data, we want the best (highest scoring) entry
    Map<String, dynamic>? bestSkillsEntry;
    int highestCombined = 0;
    
    for (final entry in worldSkillsData) {
      print('Skills entry: $entry');
      
      // Try different possible score field names
      final combinedScore = _safeIntConvert(
        entry['scores']?['score'] ?? 
        entry['score'] ?? 
        entry['combined'] ?? 
        entry['totalScore'] ?? 0
      );
      
      if (combinedScore > highestCombined) {
        highestCombined = combinedScore;
        bestSkillsEntry = entry;
      }
    }
    
    if (bestSkillsEntry == null) {
      print('No valid skills entry found');
      return {
        'ranking': 0,
        'combined': 0,
        'driver': 0,
        'programming': 0,
        'totalTeams': 0,
      };
    }
    
    final result = {
      'ranking': _safeIntConvert(bestSkillsEntry['rank'] ?? 0),
      'combined': _safeIntConvert(
        bestSkillsEntry['scores']?['score'] ?? 
        bestSkillsEntry['score'] ?? 
        bestSkillsEntry['combined'] ?? 0
      ),
      'driver': _safeIntConvert(
        bestSkillsEntry['scores']?['driver'] ?? 
        bestSkillsEntry['driver'] ?? 0
      ),
      'programming': _safeIntConvert(
        bestSkillsEntry['scores']?['programming'] ?? 
        bestSkillsEntry['programming'] ?? 0
      ),
      'totalTeams': _safeIntConvert(bestSkillsEntry['totalTeams'] ?? 0), // Use actual total teams if available
    };
    
    print('Parsed skills result: $result');
    return result;
  }
    
  // 1. World Skills Ranking Score (30 points)
  static double _calculateWorldSkillsRankingScore(Map<String, dynamic> worldSkills) {
    final ranking = _safeIntConvert(worldSkills['ranking']);
    final totalTeams = _safeIntConvert(worldSkills['totalTeams']);
    
    if (ranking <= 0) {
      return 0.0;
    }
    
    // If we don't have total teams info, use a reasonable estimate based on ranking
    int effectiveTotalTeams = totalTeams;
    if (effectiveTotalTeams <= 0) {
      // Estimate total teams based on ranking (conservative estimate)
      effectiveTotalTeams = (ranking * 2).clamp(100, 1000); // Assume at least 100 teams, max 1000
    }
    
    // Calculate percentile: higher percentile = better ranking
    final percentile = (effectiveTotalTeams - ranking + 1) / effectiveTotalTeams;
    return (percentile * 30.0).clamp(0.0, 30.0);
  }
  
  // 2. Skills Score Quality (25 points) + Balance Bonus (5 points) - Enhanced with relative scoring
  static Future<Map<String, double>> _calculateSkillsScoreQuality(
    Map<String, dynamic> worldSkills, {
    int? seasonId,
  }) async {
    // Safe type conversion for API data
    final combined = _safeIntConvert(worldSkills['combined']);
    final driver = _safeIntConvert(worldSkills['driver']);
    final programming = _safeIntConvert(worldSkills['programming']);
    
    print('Skills data - Combined: $combined, Driver: $driver, Programming: $programming');
    
    double qualityScore = 0.0;
    double balanceBonus = 0.0;
    
    if (combined > 0) {
      // Get current season skills context for relative scoring
      final skillsContext = await _getSeasonSkillsContext(seasonId);
      
      if (skillsContext != null) {
        // Calculate percentile based on actual scores from the same season
        final percentile = _calculateSkillsPercentile(combined, skillsContext);
        qualityScore = percentile * 25.0; // Convert percentile to 25-point scale
        
        print('Relative scoring - Season: ${seasonId ?? "current"}, '
              'Score: $combined, Percentile: ${(percentile * 100).toStringAsFixed(1)}%, '
              'Quality Score: ${qualityScore.toStringAsFixed(2)}');
        
        // Enhanced balance scoring with context
        if (driver > 0 && programming > 0) {
          final driverPercentile = _calculateSkillsPercentile(driver, skillsContext, skillType: 'driver');
          final programmingPercentile = _calculateSkillsPercentile(programming, skillsContext, skillType: 'programming');
          
          // Reward teams that are strong in both areas relative to season performance
          final minPercentile = driverPercentile < programmingPercentile ? driverPercentile : programmingPercentile;
          final balanceRatio = minPercentile / ((driverPercentile + programmingPercentile) / 2.0);
          balanceBonus = balanceRatio * 5.0;
          
          print('Enhanced balance - Driver: ${(driverPercentile * 100).toStringAsFixed(1)}%, '
                'Programming: ${(programmingPercentile * 100).toStringAsFixed(1)}%, '
                'Balance Bonus: ${balanceBonus.toStringAsFixed(2)}');
        }
      } else {
        // Fallback to adaptive fixed thresholds based on season progression
        print('No season context available - using adaptive thresholds');
        final adaptiveThreshold = _getAdaptiveScoreThreshold(seasonId);
        final normalizedScore = (combined / adaptiveThreshold).clamp(0.0, 1.0);
      qualityScore = normalizedScore * 25.0;
      
        print('Adaptive scoring - Threshold: $adaptiveThreshold, '
              'Normalized: ${normalizedScore.toStringAsFixed(3)}, '
              'Quality Score: ${qualityScore.toStringAsFixed(2)}');
      
        // Standard balance bonus for fallback
      if (driver > 0 && programming > 0) {
        final maxSkill = driver > programming ? driver : programming;
        final balance = 1.0 - (driver - programming).abs() / maxSkill;
        balanceBonus = balance * 5.0;
        }
      }
    } else {
      print('No combined score available for skills quality calculation');
    }
    
    return {
      'quality': qualityScore,
      'balance': balanceBonus,
    };
  }
  
  // Get skills context for the current season (scores distribution)
  static Future<Map<String, dynamic>?> _getSeasonSkillsContext(int? seasonId) async {
    try {
      final currentSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
      print('Fetching skills context for season: $currentSeasonId');
      
      // Get world skills rankings for current season (multiple pages for better sample)
      final allSkillsData = <dynamic>[];
      
      // Fetch first 3 pages to get a good sample of current season scores
      for (int page = 1; page <= 3; page++) {
        final pageData = await RobotEventsAPI.getWorldSkillsRankings(
          seasonId: currentSeasonId,
          page: page,
        );
        
        if (pageData.isEmpty) break; // No more data
        allSkillsData.addAll(pageData);
        
        // If we get less than full page, we've reached the end
        if (pageData.length < ApiConfig.defaultPageSize) break;
      }
      
      if (allSkillsData.isEmpty) {
        print('No skills data found for season $currentSeasonId');
        return null;
      }
      
      // Parse and sort scores
      final combinedScores = <int>[];
      final driverScores = <int>[];
      final programmingScores = <int>[];
      
      for (final entry in allSkillsData) {
        final combined = _safeIntConvert(entry['scores']?['score'] ?? entry['score'] ?? 0);
        final driver = _safeIntConvert(entry['scores']?['driver'] ?? entry['driver'] ?? 0);
        final programming = _safeIntConvert(entry['scores']?['programming'] ?? entry['programming'] ?? 0);
        
        if (combined > 0) combinedScores.add(combined);
        if (driver > 0) driverScores.add(driver);
        if (programming > 0) programmingScores.add(programming);
      }
      
      // Sort scores for percentile calculations
      combinedScores.sort();
      driverScores.sort();
      programmingScores.sort();
      
      final context = {
        'seasonId': currentSeasonId,
        'totalTeams': allSkillsData.length,
        'combinedScores': combinedScores,
        'driverScores': driverScores,
        'programmingScores': programmingScores,
        'highScore': combinedScores.isNotEmpty ? combinedScores.last : 0,
        'medianScore': combinedScores.isNotEmpty ? combinedScores[combinedScores.length ~/ 2] : 0,
        'averageScore': combinedScores.isNotEmpty ? combinedScores.reduce((a, b) => a + b) / combinedScores.length : 0.0,
      };
      
      print('Skills context loaded - Teams: ${context['totalTeams']}, '
            'High: ${context['highScore']}, Median: ${context['medianScore']}, '
            'Avg: ${(context['averageScore'] as double).toStringAsFixed(1)}');
      
      return context;
    } catch (e) {
      print('Error fetching season skills context: $e');
      return null;
    }
  }
  
  // Calculate percentile of a score within the season context
  static double _calculateSkillsPercentile(
    int score, 
    Map<String, dynamic> context, {
    String skillType = 'combined',
  }) {
    List<int> scores;
    
    switch (skillType) {
      case 'driver':
        scores = context['driverScores'] as List<int>;
        break;
      case 'programming':
        scores = context['programmingScores'] as List<int>;
        break;
      default:
        scores = context['combinedScores'] as List<int>;
    }
    
    if (scores.isEmpty) return 0.0;
    
    // Count scores below this team's score
    int scoresBeat = 0;
    for (final otherScore in scores) {
      if (score > otherScore) {
        scoresBeat++;
      }
    }
    
    // Calculate percentile (0.0 to 1.0)
    final percentile = scoresBeat / scores.length;
    
    print('Percentile calculation ($skillType) - Score: $score beats $scoresBeat/${scores.length} = ${(percentile * 100).toStringAsFixed(1)}%');
    
    return percentile;
  }
  
  // Adaptive threshold based on season progression (fallback when no context available)
  static double _getAdaptiveScoreThreshold(int? seasonId) {
    final currentSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
    
    // Estimate season progression (this could be enhanced with actual date-based logic)
    // For now, use season ID to estimate relative timing
    double baseThreshold = 300.0; // Default VEX IQ max
    
    // Adjust threshold based on season (newer seasons might have higher scores)
    switch (currentSeasonId) {
      case 196: // Mix & Match 2025-2026 (current)
        baseThreshold = 280.0; // Slightly lower since it's newer
        break;
      case 189: // Rapid Relay 2024-2025
        baseThreshold = 320.0; // Full season data available
        break;
      case 180: // Full Volume 2023-2024
        baseThreshold = 310.0; // Mature season
        break;
      default:
        baseThreshold = 300.0; // Default
    }
    
    print('Using adaptive threshold: $baseThreshold for season $currentSeasonId');
    return baseThreshold;
  }
  
  // Helper method to safely convert various data types to int
  static int _safeIntConvert(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }
  
  // 3. Competition Performance (20 points)
  static double _calculateCompetitionPerformance(List<dynamic>? rankingsData) {
    if (rankingsData == null || rankingsData.isEmpty) {
      return 0.0;
    }
    
    // Calculate average ranking across all competitions
    double totalRank = 0.0;
    int validRankings = 0;
    
    for (final ranking in rankingsData) {
      final rank = ranking['rank'] as int?;
      if (rank != null && rank > 0) {
        totalRank += rank.toDouble();
        validRankings++;
      }
    }
    
    if (validRankings == 0) {
      return 0.0;
    }
    
    final avgRank = totalRank / validRankings;
    
    // Better average ranking = higher score
    // Use a more robust scoring system that won't go negative
    double rankScore;
    if (avgRank <= 1) {
      rankScore = 20.0; // Perfect ranking
    } else if (avgRank <= 5) {
      rankScore = 18.0; // Top 5 average
    } else if (avgRank <= 10) {
      rankScore = 15.0; // Top 10 average
    } else if (avgRank <= 15) {
      rankScore = 12.0; // Top 15 average
    } else if (avgRank <= 20) {
      rankScore = 8.0;  // Top 20 average
    } else if (avgRank <= 25) {
      rankScore = 5.0;  // Top 25 average
    } else {
      rankScore = 2.0;  // Lower rankings
    }
    
    return rankScore.clamp(0.0, 20.0);
  }
  
  // 4. Award Excellence (20 points)
  static double _calculateAwardExcellence(List<dynamic>? awardsData) {
    if (awardsData == null || awardsData.isEmpty) {
      return 0.0;
    }
    
    double awardScore = 0.0;
    
    for (final award in awardsData) {
      final title = (award['title'] as String? ?? '').toLowerCase();
      
      // Award scoring based on VRC RoboScout implementation
      if (title.contains('excellence')) {
        awardScore += 4.0;
      } else if (title.contains('champion')) {
        awardScore += 3.0;
      } else if (title.contains('design')) {
        awardScore += 2.5;
      } else if (title.contains('innovate')) {
        awardScore += 2.0;
      } else if (title.contains('teamwork')) {
        awardScore += 1.5;
      } else {
        awardScore += 1.0; // Other awards
      }
    }
    
    // Cap at 20 points maximum
    return awardScore.clamp(0.0, 20.0);
  }
  
  // 5. Event Participation (15 points) - For when skills data unavailable
  static double _calculateEventParticipation(List<dynamic>? eventsData) {
    if (eventsData == null || eventsData.isEmpty) {
      return 0.0;
    }
    
    final eventCount = eventsData.length;
    
    // Score based on number of events attended
    // 1-2 events: 25% of max
    // 3-5 events: 50% of max  
    // 6-8 events: 75% of max
    // 9+ events: 100% of max
    double participationScore = 0.0;
    
    if (eventCount >= 9) {
      participationScore = 15.0;
    } else if (eventCount >= 6) {
      participationScore = 11.25; // 75%
    } else if (eventCount >= 3) {
      participationScore = 7.5;   // 50%
    } else if (eventCount >= 1) {
      participationScore = 3.75;  // 25%
    }
    
    return participationScore;
  }
  
  // 6. Consistency Bonus (15 points) - For when skills data unavailable
  static double _calculateConsistencyBonus(List<dynamic>? rankingsData) {
    if (rankingsData == null || rankingsData.isEmpty) {
      return 0.0;
    }
    
    final rankings = <int>[];
    for (final ranking in rankingsData) {
      final rank = ranking['rank'] as int?;
      if (rank != null && rank > 0) {
        rankings.add(rank);
      }
    }
    
    if (rankings.length < 2) {
      return 0.0; // Need at least 2 rankings to calculate consistency
    }
    
    // Calculate consistency based on standard deviation of rankings
    final mean = rankings.reduce((a, b) => a + b) / rankings.length;
    final variance = rankings.map((rank) => (rank - mean) * (rank - mean)).reduce((a, b) => a + b) / rankings.length;
    final stdDev = variance > 0 ? (variance * variance) : 0; // Simplified std dev calc
    
    // Lower standard deviation = higher consistency = higher score
    // Scale inversely with std dev (max 15 points for very consistent performance)
    final consistencyScore = (15.0 / (1.0 + stdDev / 5.0)).clamp(0.0, 15.0);
    
    return consistencyScore;
  }
  
  // Get performance tier based on percentage (matches VRC RoboScout implementation)
  static String getPerformanceTier(double percentage, String grade) {
    switch (percentage) {
      case >= 90:
      return 'Elite';
      case >= 80:
      return 'Very High';
      case >= 70:
      return 'High';
      case >= 60:
      return 'High Mid';
      case >= 50:
      return 'Mid';
      case >= 40:
      return 'Low Mid';
      default:
      return 'Developing';
    }
  }
  
  // Get tier color based on performance level
  static Color getTierColor(String tier) {
    switch (tier) {
      case 'Elite':
        return const Color(0xFF4CAF50); // Green
      case 'Very High':
        return const Color(0xFF8BC34A); // Light Green
      case 'High':
        return const Color(0xFFCDDC39); // Lime
      case 'High Mid':
        return const Color(0xFFFFEB3B); // Yellow
      case 'Mid':
        return const Color(0xFFFF9800); // Orange
      case 'Low Mid':
        return const Color(0xFFFF5722); // Deep Orange
      case 'Developing':
        return const Color(0xFF9E9E9E); // Grey
      default:
        return const Color(0xFF9E9E9E);
    }
  }
  
  // Get detailed score breakdown for display
  static Future<Map<String, dynamic>> getScoreBreakdown({
    required Team team,
    List<dynamic>? worldSkillsData,
    List<dynamic>? eventsData,
    List<dynamic>? awardsData,
    List<dynamic>? rankingsData,
    int? seasonId,
  }) async {
    final worldSkills = await _parseWorldSkillsWithFallback(
      worldSkillsData,
      team.number,
      seasonId,
    );
    
    // Calculate individual components
    final worldSkillsScore = _calculateWorldSkillsRankingScore(worldSkills);
    final skillsScores = await _calculateSkillsScoreQuality(worldSkills, seasonId: seasonId);
    final competitionScore = _calculateCompetitionPerformance(rankingsData);
    final awardScore = _calculateAwardExcellence(awardsData);
    
    final totalScore = worldSkillsScore + skillsScores['quality']! + 
                      skillsScores['balance']! + competitionScore + awardScore;
    final maxScore = 100.0 + (skillsScores['balance']! > 0 ? 5.0 : 0.0);
    
    return {
      'worldSkillsRanking': {
        'score': worldSkillsScore,
        'maxScore': 30.0,
        'description': 'Percentile ranking among all teams',
        'ranking': worldSkills['ranking'],
        'totalTeams': worldSkills['totalTeams'],
      },
      'skillsQuality': {
        'score': skillsScores['quality']!,
        'maxScore': 25.0,
        'description': 'Normalized score based on 300-point scale',
        'combinedScore': worldSkills['combined'],
      },
      'skillsBalance': {
        'score': skillsScores['balance']!,
        'maxScore': 5.0,
        'description': 'Bonus for balanced driver vs programming skills',
        'driverScore': worldSkills['driver'],
        'programmingScore': worldSkills['programming'],
      },
      'competitionPerformance': {
        'score': competitionScore,
        'maxScore': 20.0,
        'description': 'Based on average qualification ranking',
        'eventCount': rankingsData?.length ?? 0,
      },
      'awardExcellence': {
        'score': awardScore,
        'maxScore': 20.0,
        'description': 'Weighted scoring for different award types',
        'awardCount': awardsData?.length ?? 0,
      },
      'totalScore': totalScore,
      'maxPossibleScore': maxScore,
      'percentage': (totalScore / maxScore) * 100.0,
    };
  }
  
  // Fallback scoring for teams without detailed data
  static String calculateBasicScore(Team team) {
    double score = 0.0;
    
    // Registration status
    if (team.registered) {
      score += 40.0;
          } else {
      score += 15.0; // Listed but not fully registered
    }
    
    // Event participation (estimated)
    final eventCount = team.events.length;
    score += (eventCount * 8.0).clamp(0.0, 25.0);
    
    // Awards (estimated)
    final awardCount = team.awards.length;
    score += (awardCount * 5.0).clamp(0.0, 20.0);
    
    // Grade level bonus
    if (team.grade.toLowerCase().contains('elementary')) {
      score += 8.0;
    } else if (team.grade.toLowerCase().contains('middle')) {
      score += 5.0;
    }
    
    // Complete profile bonus
    if (team.name.isNotEmpty && team.organization.isNotEmpty) {
      score += 5.0;
    }
    
    return score.toStringAsFixed(1);
  }
} 