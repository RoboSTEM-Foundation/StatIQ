import 'dart:math' as math;
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/trueskill_scoring.dart';
import 'package:stat_iq/utils/logger.dart';
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
    AppLogger.d('=== statIQ Score Calculation Debug for ${team.number} ===');
    
    double totalScore = 0.0;
    double maxScore = 100.0;
    
    // Get multi-season data for enhanced scoring
    final multiSeasonData = await _getMultiSeasonData(team, seasonId);
    
    // Fetch actual world skills rankings to get true global position
    Map<String, dynamic> worldSkills = await _getActualWorldSkillsRanking(
      team, 
      worldSkillsData,
      seasonId,
    );
    
    final hasSkillsData = !(worldSkills['estimated'] == true);
    
    // Calculate TrueSkill ratings
    List<Map<String, double>> trueskillRatings = [];
    
    if (hasSkillsData) {
      // TrueSkill rating from actual world skills leaderboard
      final skillsRating = await TrueSkillScoring.calculateSkillsRating(
        teamNumber: team.number,
        teamRanking: worldSkills['ranking'] ?? 0,
        totalTeams: worldSkills['totalTeams'] ?? 0,
        seasonId: seasonId,
      );
      trueskillRatings.add(skillsRating);
      AppLogger.d('TrueSkill Skills Rating (World Rankings): mu=${skillsRating['mu']!.toStringAsFixed(2)}, sigma=${skillsRating['sigma']!.toStringAsFixed(2)}, ranking=${worldSkills['ranking']}/${worldSkills['totalTeams']}');
    }
    
    // Get teamwork scores from all events (signature events + any event with 200+ teamwork scores)
    final teamworkScores = await _getTeamworkScoresFromAllEvents(team, seasonId);
    if (teamworkScores.isNotEmpty) {
      final teamworkRating = await TrueSkillScoring.calculateTeamworkRating(
        teamNumber: team.number,
        teamworkScores: teamworkScores,
      );
      trueskillRatings.add(teamworkRating);
      AppLogger.d('TrueSkill Teamwork Rating: mu=${teamworkRating['mu']!.toStringAsFixed(2)}, sigma=${teamworkRating['sigma']!.toStringAsFixed(2)}, matches=${teamworkRating['matches']}');
    }
    
    // Combine TrueSkill ratings
    final combinedRating = trueskillRatings.isNotEmpty
        ? TrueSkillScoring.combineRatings(trueskillRatings)
        : null;
    
    if (hasSkillsData) {
      // Standard scoring with skills data
      // 1. World Skills Ranking (35 points) - Increased weight for better assessment
      final worldSkillsScore = _calculateWorldSkillsRankingScore(worldSkills);
      totalScore += worldSkillsScore * (35.0 / 30.0); // Scale up to 35 points
      AppLogger.d('World Skills Ranking Score: ${(worldSkillsScore * 35.0 / 30.0).toStringAsFixed(2)} / 35.0');
      
      // 2. TrueSkill Rating Bonus (20 points) - Increased weight for better skill assessment
      if (combinedRating != null) {
        final trueskillBonus = (combinedRating['mu']! / 50.0) * 20.0;
        totalScore += trueskillBonus;
        maxScore += 20.0;
        AppLogger.d('TrueSkill Rating Bonus: ${trueskillBonus.toStringAsFixed(2)} / 20.0');
      }
      
      // 3. Skills Score Quality (25 points) + Balance Bonus (5 points)
      final skillsScores = await _calculateSkillsScoreQuality(worldSkills, seasonId: seasonId);
      totalScore += skillsScores['quality']!;
      totalScore += skillsScores['balance']!;
      if (skillsScores['balance']! > 0) {
        maxScore += 5.0; // Balance bonus increases max score
      }
      AppLogger.d('Skills Score Quality: ${skillsScores['quality']!.toStringAsFixed(2)} / 25.0');
      AppLogger.d('Skills Balance Bonus: ${skillsScores['balance']!.toStringAsFixed(2)} / 5.0');
      
      // 4. Competition Performance (20 points) - enhanced with multi-season data
      final competitionScore = await _calculateCompetitionPerformanceEnhanced(
        rankingsData, 
        multiSeasonData['rankings'],
      );
      totalScore += competitionScore;
      AppLogger.d('Competition Performance: ${competitionScore.toStringAsFixed(2)} / 20.0');
      
      // 5. Award Excellence (20 points) - enhanced with multi-season data
      final awardScore = await _calculateAwardExcellenceEnhanced(
        awardsData,
        multiSeasonData['awards'],
      );
      totalScore += awardScore;
      AppLogger.d('Award Excellence: ${awardScore.toStringAsFixed(2)} / 20.0');
      
      // 6. World Qualification & Achievement Bonuses (10 points)
      final achievementBonus = await _calculateAchievementBonuses(
        team,
        eventsData,
        multiSeasonData['events'],
        seasonId,
      );
      totalScore += achievementBonus;
      maxScore += 10.0;
      AppLogger.d('Achievement Bonuses: ${achievementBonus.toStringAsFixed(2)} / 10.0');
    } else {
      // Enhanced scoring without skills data (redistribute weights)
      AppLogger.d('No skills data - using enhanced competition-based scoring');
      
      // 1. Competition Performance (40 points - doubled weight) - enhanced with multi-season
      final competitionScore = await _calculateCompetitionPerformanceEnhanced(
        rankingsData,
        multiSeasonData['rankings'],
      ) * 2.0;
      totalScore += competitionScore;
      AppLogger.d('Enhanced Competition Performance: ${competitionScore.toStringAsFixed(2)} / 40.0');
      
      // 2. Award Excellence (30 points - increased weight) - enhanced with multi-season
      final awardScore = await _calculateAwardExcellenceEnhanced(
        awardsData,
        multiSeasonData['awards'],
      ) * 1.5;
      totalScore += awardScore;
      AppLogger.d('Enhanced Award Excellence: ${awardScore.toStringAsFixed(2)} / 30.0');
      
      // 3. Event Participation Bonus (15 points)
      final participationScore = _calculateEventParticipation(eventsData);
      totalScore += participationScore;
      AppLogger.d('Event Participation Score: ${participationScore.toStringAsFixed(2)} / 15.0');
      
      // 4. Consistency Bonus (15 points)
      final consistencyScore = _calculateConsistencyBonus(rankingsData);
      totalScore += consistencyScore;
      AppLogger.d('Consistency Bonus: ${consistencyScore.toStringAsFixed(2)} / 15.0');
    }
    
    // Calculate final percentage
    final percentage = (totalScore / maxScore) * 100.0;
    
    AppLogger.d('Total Score: ${totalScore.toStringAsFixed(2)} / ${maxScore.toStringAsFixed(2)}');
    AppLogger.d('Percentage: ${percentage.toStringAsFixed(2)}%');
    AppLogger.d('Performance Tier: ${getPerformanceTier(percentage)}');
    AppLogger.d('=== End statIQ Score Calculation ===');
    
    return percentage.toStringAsFixed(1);
  }
  
  /// Get data from multiple seasons for enhanced scoring
  static Future<Map<String, dynamic>> _getMultiSeasonData(Team team, int? currentSeasonId) async {
    final currentSeason = currentSeasonId ?? ApiConfig.getSelectedSeasonId();
    final allRankings = <dynamic>[];
    final allAwards = <dynamic>[];
    
    // Get data from current season and past 2 seasons
    final seasonsToCheck = [
      currentSeason, // Current season
      189, // Rapid Relay 2024-2025
      180, // Full Volume 2023-2024
    ];
    
    for (final seasonId in seasonsToCheck) {
      if (seasonId == currentSeason) {
        // Current season data is already provided, skip
        continue;
      }
      
      try {
        // Fetch rankings and awards from past seasons
        final pastRankings = await RobotEventsAPI.getTeamRankings(
          teamId: team.id,
          seasonId: seasonId,
        );
        final pastAwards = await RobotEventsAPI.getTeamAwards(
          teamId: team.id,
          seasonId: seasonId,
        );
        
        allRankings.addAll(pastRankings);
        allAwards.addAll(pastAwards);
        
        AppLogger.d('Fetched ${pastRankings.length} rankings and ${pastAwards.length} awards from season $seasonId');
      } catch (e) {
        AppLogger.d('Error fetching data from season $seasonId: $e');
      }
    }
    
    return {
      'rankings': allRankings,
      'awards': allAwards,
    };
  }
  
  /// Get teamwork scores from all events (signature events + any event with 200+ teamwork scores)
  static Future<List<Map<String, dynamic>>> _getTeamworkScoresFromAllEvents(
    Team team,
    int? seasonId,
  ) async {
    final teamworkScores = <Map<String, dynamic>>[];
    const minTeamworkScore = 200.0; // Minimum score threshold
    
    try {
      // Get team events
      final events = await RobotEventsAPI.getTeamEvents(
        teamId: team.id,
        seasonId: seasonId ?? ApiConfig.getSelectedSeasonId(),
      );
      
      // Separate signature events and regular events
      final signatureEvents = events.where((event) {
        final eventName = event.name.toLowerCase();
        return eventName.contains('signature');
      }).toList();
      
      final regularEvents = events.where((event) {
        final eventName = event.name.toLowerCase();
        return !eventName.contains('signature');
      }).toList();
      
      AppLogger.d('Found ${signatureEvents.length} signature events and ${regularEvents.length} regular events for team ${team.number}');
      
      // Process all events (signature events always included, regular events only if 200+)
      final eventsToProcess = <Event>[];
      eventsToProcess.addAll(signatureEvents);
      eventsToProcess.addAll(regularEvents);
      
      // Create a set of signature event IDs for quick lookup
      final signatureEventIds = signatureEvents.map((e) => e.id).toSet();
      
      // For each event, get teamwork match scores
      for (final event in eventsToProcess) {
        try {
          final isSignatureEvent = signatureEventIds.contains(event.id);
          final eventDetails = await RobotEventsAPI.getEventDetails(eventId: event.id);
          final divisions = eventDetails['divisions'] as List<dynamic>? ?? [];
          
          for (final division in divisions) {
            final divisionId = division['id'] as int?;
            if (divisionId == null) continue;
            
            final matches = await RobotEventsAPI.getEventMatches(
              eventId: event.id,
              divisionId: divisionId,
            );
            
            // Find teamwork matches
            for (final match in matches) {
              final matchName = (match['name'] as String? ?? '').toLowerCase();
              if (matchName.contains('teamwork') || matchName.contains('team work')) {
                final alliances = match['alliances'] as List<dynamic>? ?? [];
                
                for (final alliance in alliances) {
                  final teams = alliance['teams'] as List<dynamic>? ?? [];
                  final allianceScore = (alliance['score'] as num?)?.toDouble() ?? 0.0;
                  
                  // Check if this team is in this alliance
                  bool teamInAlliance = false;
                  for (final teamData in teams) {
                    final teamInfo = teamData['team'] as Map<String, dynamic>?;
                    final teamNumber = (teamInfo?['name'] as String? ?? '').toUpperCase();
                    if (teamNumber == team.number.toUpperCase()) {
                      teamInAlliance = true;
                      break;
                    }
                  }
                  
                  // Include score if:
                  // 1. Team is in alliance AND
                  // 2. (It's a signature event OR score is 200+)
                  if (teamInAlliance && allianceScore > 0) {
                    if (isSignatureEvent || allianceScore >= minTeamworkScore) {
                      teamworkScores.add({
                        'score': allianceScore,
                        'eventId': event.id,
                        'eventName': event.name,
                        'matchName': match['name'] ?? 'Unknown',
                        'isSignature': isSignatureEvent,
                      });
                      AppLogger.d('Added teamwork score: ${allianceScore} from ${isSignatureEvent ? "signature" : "regular"} event ${event.name}');
                    } else {
                      AppLogger.d('Skipped teamwork score: ${allianceScore} (below ${minTeamworkScore} threshold) from ${event.name}');
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          AppLogger.d('Error getting teamwork scores from event ${event.id}: $e');
        }
      }
      
      AppLogger.d('Found ${teamworkScores.length} teamwork scores (${teamworkScores.where((s) => s['isSignature'] == true).length} from signature events, ${teamworkScores.where((s) => s['isSignature'] == false).length} from regular events with 200+ scores) for team ${team.number}');
    } catch (e) {
      AppLogger.d('Error getting teamwork scores: $e');
    }
    
    return teamworkScores;
  }
  
  /// Enhanced competition performance calculation with multi-season data
  static Future<double> _calculateCompetitionPerformanceEnhanced(
    List<dynamic>? currentRankings,
    List<dynamic>? pastRankings,
  ) async {
    final allRankings = <dynamic>[];
    if (currentRankings != null) allRankings.addAll(currentRankings);
    if (pastRankings != null) allRankings.addAll(pastRankings);
    
    return _calculateCompetitionPerformance(allRankings);
  }
  
  /// Enhanced award excellence calculation with multi-season data
  static Future<double> _calculateAwardExcellenceEnhanced(
    List<dynamic>? currentAwards,
    List<dynamic>? pastAwards,
  ) async {
    final allAwards = <dynamic>[];
    if (currentAwards != null) allAwards.addAll(currentAwards);
    if (pastAwards != null) allAwards.addAll(pastAwards);
    
    return _calculateAwardExcellence(allAwards);
  }
  
  /// Get actual world skills ranking by fetching global leaderboard and finding team position
  static Future<Map<String, dynamic>> _getActualWorldSkillsRanking(
    Team team,
    List<dynamic>? worldSkillsData,
    int? seasonId,
  ) async {
    try {
      final targetSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
      AppLogger.d('Fetching actual world skills rankings for team ${team.number}');
      
      // Fetch world skills rankings (multiple pages to find team)
      final allRankings = <dynamic>[];
      int teamRanking = 0;
      Map<String, dynamic>? teamSkillsEntry;
      
      // Search through multiple pages to find the team
      for (int page = 1; page <= 10; page++) {
        final pageData = await RobotEventsAPI.getWorldSkillsRankings(
          seasonId: targetSeasonId,
          page: page,
        );
        
        if (pageData.isEmpty) break;
        
        // Search for team in this page
        for (final entry in pageData) {
          final teamNumber = (entry['team']?['number'] ?? entry['team_number'] ?? '').toString().toUpperCase();
          if (teamNumber == team.number.toUpperCase()) {
            teamSkillsEntry = entry;
            teamRanking = allRankings.length + pageData.indexOf(entry) + 1;
            AppLogger.d('Found team ${team.number} at world ranking #$teamRanking');
            break;
          }
        }
        
        if (teamSkillsEntry != null) break; // Found team, stop searching
        
        allRankings.addAll(pageData);
        
        // If we got less than full page, we've reached the end
        if (pageData.length < ApiConfig.defaultPageSize) break;
      }
      
      // If we found the team in world rankings, use that data
      if (teamSkillsEntry != null && teamRanking > 0) {
        final totalTeams = allRankings.length + (teamRanking > allRankings.length ? 1 : 0);
        // Estimate total teams if we didn't reach the end (add buffer)
        final estimatedTotal = totalTeams < 100 ? 1000 : totalTeams;
        
        return {
          'ranking': teamRanking,
          'combined': _safeIntConvert(
            teamSkillsEntry['scores']?['score'] ?? 
            teamSkillsEntry['score'] ?? 
            teamSkillsEntry['combined'] ?? 0
          ),
          'driver': _safeIntConvert(
            teamSkillsEntry['scores']?['driver'] ?? 
            teamSkillsEntry['driver'] ?? 0
          ),
          'programming': _safeIntConvert(
            teamSkillsEntry['scores']?['programming'] ?? 
            teamSkillsEntry['programming'] ?? 0
          ),
          'totalTeams': estimatedTotal,
          'fromWorldRankings': true,
        };
      }
      
      // Fallback: Try parsing provided skills data (event-level)
      if (worldSkillsData != null && worldSkillsData.isNotEmpty) {
        AppLogger.d('Team not found in world rankings, using event-level skills data');
        return _parseWorldSkills(worldSkillsData);
      }
      
      // No data available
      AppLogger.d('No skills data available - using competition performance estimate');
      return {
        'ranking': 0,
        'combined': 0,
        'driver': 0,
        'programming': 0,
        'totalTeams': 0,
        'estimated': true,
      };
    } catch (e) {
      AppLogger.d('Error fetching world skills ranking: $e');
      // Fallback to parsing provided data
      if (worldSkillsData != null && worldSkillsData.isNotEmpty) {
        return _parseWorldSkills(worldSkillsData);
      }
      return {
        'ranking': 0,
        'combined': 0,
        'driver': 0,
        'programming': 0,
        'totalTeams': 0,
        'estimated': true,
      };
    }
  }
  
    // Parse world skills data with enhanced fallback
  static Future<Map<String, dynamic>> _parseWorldSkillsWithFallback(
    List<dynamic>? worldSkillsData,
    String teamNumber,
    int? seasonId,
  ) async {
    // Try RobotEvents API data
    if (worldSkillsData != null && worldSkillsData.isNotEmpty) {
      AppLogger.d('Using RobotEvents skills data');
      return _parseWorldSkills(worldSkillsData);
    }
    
    // Skills data unavailable - estimate from competition performance
    AppLogger.d('No skills data available - using competition performance estimate');
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
      AppLogger.d('No skills data provided to parse');
      return {
        'ranking': 0,
        'combined': 0,
        'driver': 0,
        'programming': 0,
        'totalTeams': 0,
      };
    }
    
    AppLogger.d('Parsing skills data with ${worldSkillsData.length} records');
    
    // For skills data, we want the best (highest scoring) entry
    Map<String, dynamic>? bestSkillsEntry;
    int highestCombined = 0;
    
    for (final entry in worldSkillsData) {
      AppLogger.d('Skills entry: $entry');
      
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
      AppLogger.d('No valid skills entry found');
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
    
    AppLogger.d('Parsed skills result: $result');
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
    
    AppLogger.d('Skills data - Combined: $combined, Driver: $driver, Programming: $programming');
    
    double qualityScore = 0.0;
    double balanceBonus = 0.0;
    
    if (combined > 0) {
      // Get current season skills context for relative scoring
      final skillsContext = await _getSeasonSkillsContext(seasonId);
      
      if (skillsContext != null) {
        // Calculate percentile based on actual scores from the same season
        final percentile = _calculateSkillsPercentile(combined, skillsContext);
        qualityScore = percentile * 25.0; // Convert percentile to 25-point scale
        
        AppLogger.d('Relative scoring - Season: ${seasonId ?? "current"}, '
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
          
          AppLogger.d('Enhanced balance - Driver: ${(driverPercentile * 100).toStringAsFixed(1)}%, '
                'Programming: ${(programmingPercentile * 100).toStringAsFixed(1)}%, '
                'Balance Bonus: ${balanceBonus.toStringAsFixed(2)}');
        }
      } else {
        // Fallback: Use ranking-based scoring instead of fixed threshold
        AppLogger.d('No season context available - using ranking-based scoring');
        final ranking = _safeIntConvert(worldSkills['ranking']);
        final totalTeams = _safeIntConvert(worldSkills['totalTeams']);
        
        if (ranking > 0 && totalTeams > 0) {
          // Calculate percentile based on ranking (better ranking = higher percentile)
          final percentile = (totalTeams - ranking + 1) / totalTeams;
          qualityScore = percentile * 25.0;
          
          AppLogger.d('Ranking-based scoring - Ranking: $ranking, Total Teams: $totalTeams, '
                'Percentile: ${(percentile * 100).toStringAsFixed(1)}%, '
                'Quality Score: ${qualityScore.toStringAsFixed(2)}');
        } else {
          // If no ranking data, use a conservative estimate
          AppLogger.d('No ranking data available - using conservative estimate');
          qualityScore = 10.0; // Default to middle-low score
        }
      
        // Standard balance bonus for fallback
        if (driver > 0 && programming > 0) {
          final maxSkill = driver > programming ? driver : programming;
          final balance = 1.0 - (driver - programming).abs() / maxSkill;
          balanceBonus = balance * 5.0;
        }
      }
    } else {
      AppLogger.d('No combined score available for skills quality calculation');
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
      AppLogger.d('Fetching skills context for season: $currentSeasonId');
      
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
        AppLogger.d('No skills data found for season $currentSeasonId');
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
      
      AppLogger.d('Skills context loaded - Teams: ${context['totalTeams']}, '
            'High: ${context['highScore']}, Median: ${context['medianScore']}, '
            'Avg: ${(context['averageScore'] as double).toStringAsFixed(1)}');
      
      return context;
    } catch (e) {
      AppLogger.d('Error fetching season skills context: $e');
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
    
    AppLogger.d('Percentile calculation ($skillType) - Score: $score beats $scoresBeat/${scores.length} = ${(percentile * 100).toStringAsFixed(1)}%');
    
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
    
    AppLogger.d('Using adaptive threshold: $baseThreshold for season $currentSeasonId');
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
  /// Calculate achievement bonuses (world qualification, etc.)
  static Future<double> _calculateAchievementBonuses(
    Team team,
    List<dynamic>? currentEvents,
    List<dynamic>? pastEvents,
    int? seasonId,
  ) async {
    double bonus = 0.0;
    
    try {
      // Combine all events from current and past seasons
      final allEvents = <dynamic>[];
      if (currentEvents != null) allEvents.addAll(currentEvents);
      if (pastEvents != null) allEvents.addAll(pastEvents);
      
      // Check for world championship qualification/participation
      bool qualifiedForWorlds = false;
      bool participatedInWorlds = false;
      
      for (final event in allEvents) {
        final eventName = (event['name'] ?? event.name ?? '').toString().toLowerCase();
        final eventLevel = (event['level'] ?? event.level ?? '').toString().toLowerCase();
        
        // Check if it's a world championship event
        if (eventName.contains('world') || 
            eventName.contains('championship') && eventName.contains('world') ||
            eventLevel.contains('world')) {
          participatedInWorlds = true;
          qualifiedForWorlds = true;
          AppLogger.d('Found world championship participation: ${event['name'] ?? event.name}');
        }
      }
      
      // Bonus for world qualification/participation
      if (qualifiedForWorlds) {
        bonus += 5.0; // 5 points for qualifying/participating in worlds
        AppLogger.d('World qualification bonus: +5.0');
      }
      
      // Check for previous season world qualification (if current season data doesn't show it)
      if (!qualifiedForWorlds && seasonId != null) {
        final previousSeasons = [189, 180]; // Rapid Relay, Full Volume
        for (final pastSeasonId in previousSeasons) {
          if (pastSeasonId == seasonId) continue; // Skip current season
          
          try {
            final pastEvents = await RobotEventsAPI.getTeamEvents(
              teamId: team.id,
              seasonId: pastSeasonId,
            );
            
            for (final event in pastEvents) {
              final eventName = event.name.toLowerCase();
              if (eventName.contains('world') || 
                  (eventName.contains('championship') && eventName.contains('world'))) {
                bonus += 3.0; // 3 points for previous season world qualification
                AppLogger.d('Previous season world qualification bonus (season $pastSeasonId): +3.0');
                break; // Only count once per season
              }
            }
          } catch (e) {
            AppLogger.d('Error checking past season $pastSeasonId for world qualification: $e');
          }
        }
      }
      
      // Bonus for multiple signature events (shows consistent high-level performance)
      int signatureEventCount = 0;
      for (final event in allEvents) {
        final eventName = (event['name'] ?? event.name ?? '').toString().toLowerCase();
        if (eventName.contains('signature')) {
          signatureEventCount++;
        }
      }
      
      if (signatureEventCount >= 3) {
        bonus += 2.0; // 2 points for 3+ signature events
        AppLogger.d('Multiple signature events bonus ($signatureEventCount events): +2.0');
      }
      
    } catch (e) {
      AppLogger.d('Error calculating achievement bonuses: $e');
    }
    
    return bonus.clamp(0.0, 10.0); // Cap at 10 points
  }
  
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
    final stdDev = variance > 0 ? math.sqrt(variance) : 0; // Standard deviation = sqrt(variance)
    
    // Lower standard deviation = higher consistency = higher score
    // Scale inversely with std dev (max 15 points for very consistent performance)
    final consistencyScore = (15.0 / (1.0 + stdDev / 5.0)).clamp(0.0, 15.0);
    
    return consistencyScore;
  }
  
  // Get performance tier based on percentage (matches VRC RoboScout implementation)
  static String getPerformanceTier(double percentage) {
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
    final worldSkills = await _getActualWorldSkillsRanking(
      team,
      worldSkillsData,
      seasonId,
    );
    
    // Get multi-season data
    final multiSeasonData = await _getMultiSeasonData(team, seasonId);
    
    // Calculate TrueSkill ratings
    List<Map<String, double>> trueskillRatings = [];
    final hasSkillsData = !(worldSkills['estimated'] == true);
    
    if (hasSkillsData) {
      final skillsRating = await TrueSkillScoring.calculateSkillsRating(
        teamNumber: team.number,
        teamRanking: worldSkills['ranking'] ?? 0,
        totalTeams: worldSkills['totalTeams'] ?? 0,
        seasonId: seasonId,
      );
      trueskillRatings.add(skillsRating);
    }
    
    final teamworkScores = await _getTeamworkScoresFromAllEvents(team, seasonId);
    if (teamworkScores.isNotEmpty) {
      final teamworkRating = await TrueSkillScoring.calculateTeamworkRating(
        teamNumber: team.number,
        teamworkScores: teamworkScores,
      );
      trueskillRatings.add(teamworkRating);
    }
    
    final combinedRating = trueskillRatings.isNotEmpty
        ? TrueSkillScoring.combineRatings(trueskillRatings)
        : null;
    
    // Calculate individual components
    final worldSkillsScore = _calculateWorldSkillsRankingScore(worldSkills);
    final scaledWorldSkillsScore = hasSkillsData ? worldSkillsScore * (35.0 / 30.0) : 0.0;
    final trueskillBonus = combinedRating != null ? (combinedRating['mu']! / 50.0) * 20.0 : 0.0;
    final skillsScores = await _calculateSkillsScoreQuality(worldSkills, seasonId: seasonId);
    final competitionScore = await _calculateCompetitionPerformanceEnhanced(
      rankingsData,
      multiSeasonData['rankings'],
    );
    final awardScore = await _calculateAwardExcellenceEnhanced(
      awardsData,
      multiSeasonData['awards'],
    );
    final achievementBonus = await _calculateAchievementBonuses(
      team,
      eventsData,
      multiSeasonData['events'],
      seasonId,
    );
    
    final totalScore = scaledWorldSkillsScore + trueskillBonus + skillsScores['quality']! + 
                      skillsScores['balance']! + competitionScore + awardScore + achievementBonus;
    final maxScore = 100.0 + (skillsScores['balance']! > 0 ? 5.0 : 0.0) + (trueskillBonus > 0 ? 20.0 : 0.0) + (achievementBonus > 0 ? 10.0 : 0.0);
    
    return {
      'worldSkillsRanking': {
        'score': scaledWorldSkillsScore,
        'maxScore': 35.0,
        'description': 'Percentile ranking among all teams (from world leaderboard)',
        'ranking': worldSkills['ranking'],
        'totalTeams': worldSkills['totalTeams'],
      },
      'trueskillRating': {
        'score': trueskillBonus,
        'maxScore': 20.0,
        'description': 'TrueSkill rating based on skills leaderboard and teamwork performance',
        'mu': combinedRating?['mu'] ?? 0.0,
        'sigma': combinedRating?['sigma'] ?? 0.0,
        'teamworkMatches': teamworkScores.length,
      },
      'skillsQuality': {
        'score': skillsScores['quality']!,
        'maxScore': 25.0,
        'description': 'Based on percentile ranking among all teams',
        'combinedScore': worldSkills['combined'],
        'ranking': worldSkills['ranking'],
        'totalTeams': worldSkills['totalTeams'],
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
        'description': 'Based on average qualification ranking (includes past seasons)',
        'eventCount': (rankingsData?.length ?? 0) + (multiSeasonData['rankings']?.length ?? 0),
      },
      'awardExcellence': {
        'score': awardScore,
        'maxScore': 20.0,
        'description': 'Weighted scoring for different award types (includes past seasons)',
        'awardCount': (awardsData?.length ?? 0) + (multiSeasonData['awards']?.length ?? 0),
      },
      'achievementBonuses': {
        'score': achievementBonus,
        'maxScore': 10.0,
        'description': 'Bonuses for world qualification, multiple signature events, etc.',
        'worldQualified': achievementBonus >= 5.0,
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