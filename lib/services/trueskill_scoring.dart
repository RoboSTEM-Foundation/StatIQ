import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/utils/logger.dart';

/// TrueSkill-style rating system for VEX IQ teams
/// Based on Microsoft's TrueSkill algorithm adapted for robotics competitions
class TrueSkillScoring {
  // TrueSkill parameters (standard values)
  static const double initialMu = 25.0;      // Initial mean skill
  static const double initialSigma = 25.0 / 3.0; // Initial uncertainty (sigma = mu/3)
  static const double beta = 25.0 / 6.0;     // Skill variance (beta = mu/6)
  static const double tau = 25.0 / 300.0;   // Dynamics factor (tau = mu/300)
  static const double drawProbability = 0.0; // No draws in robotics competitions
  
  // Cache duration
  static const Duration cacheTtl = Duration(days: 7);
  
  /// Calculate TrueSkill rating for a team based on skills leaderboard position
  static Future<Map<String, double>> calculateSkillsRating({
    required String teamNumber,
    required int teamRanking,
    required int totalTeams,
    int? seasonId,
  }) async {
    // Get distribution context for normalization
    final distribution = await _getSkillsDistribution(seasonId: seasonId);
    
    // Calculate percentile ranking
    final percentile = totalTeams > 0 
        ? (totalTeams - teamRanking + 1) / totalTeams 
        : 0.5;
    
    // Convert percentile to TrueSkill mu (mean skill)
    // Top teams get higher mu, bottom teams get lower mu
    final mu = initialMu + (percentile - 0.5) * (initialSigma * 2);
    
    // Uncertainty decreases with more data (more teams = more confidence)
    final sigma = initialSigma * (1.0 - (totalTeams / 1000.0).clamp(0.0, 0.5));
    
    // Adjust based on distribution context
    if (distribution != null) {
      final meanScore = distribution['mean'] as double;
      final stdDevScore = distribution['stdDev'] as double;
      
      // Normalize based on actual score distribution
      final normalizedMu = _normalizeToDistribution(mu, meanScore, stdDevScore);
      return {
        'mu': normalizedMu.clamp(0.0, 50.0),
        'sigma': sigma.clamp(1.0, initialSigma),
        'percentile': percentile,
      };
    }
    
    return {
      'mu': mu.clamp(0.0, 50.0),
      'sigma': sigma.clamp(1.0, initialSigma),
      'percentile': percentile,
    };
  }
  
  /// Calculate TrueSkill rating based on teamwork scores from signature events
  static Future<Map<String, double>> calculateTeamworkRating({
    required String teamNumber,
    required List<Map<String, dynamic>> teamworkScores,
  }) async {
    if (teamworkScores.isEmpty) {
      return {
        'mu': initialMu,
        'sigma': initialSigma,
        'matches': 0,
      };
    }
    
    // Get distribution of teamwork scores
    final distribution = await _getTeamworkDistribution();
    
    // Calculate average teamwork score
    final avgScore = teamworkScores
        .map((s) => (s['score'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b) / teamworkScores.length;
    
    // Convert to TrueSkill mu
    double mu = initialMu;
    if (distribution != null) {
      final meanScore = distribution['mean'] as double;
      final stdDevScore = distribution['stdDev'] as double;
      
      // Normalize score to distribution
      final zScore = (avgScore - meanScore) / (stdDevScore > 0 ? stdDevScore : 1.0);
      mu = initialMu + zScore * beta;
    } else {
      // Fallback: normalize to typical teamwork score range (0-300)
      mu = initialMu + ((avgScore / 300.0) - 0.5) * (initialSigma * 2);
    }
    
    // Uncertainty decreases with more matches
    final matchCount = teamworkScores.length;
    final sigma = initialSigma / (1.0 + matchCount * 0.1).clamp(1.0, 5.0);
    
    return {
      'mu': mu.clamp(0.0, 50.0),
      'sigma': sigma.clamp(1.0, initialSigma),
      'matches': matchCount.toDouble(),
      'avgScore': avgScore,
    };
  }
  
  /// Get skills score distribution for normalization (cached)
  static Future<Map<String, dynamic>?> _getSkillsDistribution({int? seasonId}) async {
    final cacheKey = 'trueskill_skills_dist_${seasonId ?? ApiConfig.getSelectedSeasonId()}';
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(cacheKey);
      
      if (cachedString != null) {
        final cached = jsonDecode(cachedString) as Map<String, dynamic>;
        final updatedAt = DateTime.tryParse(cached['updatedAt'] as String? ?? '');
        
        if (updatedAt != null && DateTime.now().difference(updatedAt) < cacheTtl) {
          AppLogger.d('Using cached skills distribution');
          return {
            'mean': (cached['mean'] as num).toDouble(),
            'stdDev': (cached['stdDev'] as num).toDouble(),
            'min': (cached['min'] as num).toDouble(),
            'max': (cached['max'] as num).toDouble(),
          };
        }
      }
      
      // Fetch fresh distribution
      AppLogger.d('Fetching skills distribution for season ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
      final distribution = await _fetchSkillsDistribution(seasonId: seasonId);
      
      if (distribution != null) {
        // Cache the distribution
        await prefs.setString(cacheKey, jsonEncode({
          'mean': distribution['mean'],
          'stdDev': distribution['stdDev'],
          'min': distribution['min'],
          'max': distribution['max'],
          'updatedAt': DateTime.now().toIso8601String(),
        }));
      }
      
      return distribution;
    } catch (e) {
      AppLogger.d('Error getting skills distribution: $e');
      return null;
    }
  }
  
  /// Fetch skills distribution from API
  static Future<Map<String, dynamic>?> _fetchSkillsDistribution({int? seasonId}) async {
    try {
      final seasonIdToUse = seasonId ?? ApiConfig.getSelectedSeasonId();
      final allScores = <int>[];
      
      // Fetch multiple pages to get good distribution sample
      for (int page = 1; page <= 5; page++) {
        final rankings = await RobotEventsAPI.getWorldSkillsRankings(
          seasonId: seasonIdToUse,
          page: page,
        );
        
        if (rankings.isEmpty) break;
        
        for (final ranking in rankings) {
          final score = _safeIntConvert(
            ranking['scores']?['score'] ?? 
            ranking['score'] ?? 
            ranking['combined'] ?? 0
          );
          if (score > 0) {
            allScores.add(score);
          }
        }
        
        // Stop if we got less than a full page
        if (rankings.length < ApiConfig.defaultPageSize) break;
      }
      
      if (allScores.isEmpty) return null;
      
      // Calculate statistics
      allScores.sort();
      final mean = allScores.reduce((a, b) => a + b) / allScores.length;
      final variance = allScores
          .map((s) => (s - mean) * (s - mean))
          .reduce((a, b) => a + b) / allScores.length;
      final stdDev = math.sqrt(variance);
      
      return {
        'mean': mean,
        'stdDev': stdDev,
        'min': allScores.first,
        'max': allScores.last,
        'count': allScores.length,
      };
    } catch (e) {
      AppLogger.d('Error fetching skills distribution: $e');
      return null;
    }
  }
  
  /// Get teamwork score distribution (cached)
  static Future<Map<String, dynamic>?> _getTeamworkDistribution() async {
    const cacheKey = 'trueskill_teamwork_dist';
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(cacheKey);
      
      if (cachedString != null) {
        final cached = jsonDecode(cachedString) as Map<String, dynamic>;
        final updatedAt = DateTime.tryParse(cached['updatedAt'] as String? ?? '');
        
        if (updatedAt != null && DateTime.now().difference(updatedAt) < cacheTtl) {
          AppLogger.d('Using cached teamwork distribution');
          return {
            'mean': (cached['mean'] as num).toDouble(),
            'stdDev': (cached['stdDev'] as num).toDouble(),
          };
        }
      }
      
      // For now, use estimated distribution based on typical teamwork scores
      // This could be enhanced to fetch actual data from signature events
      final distribution = {
        'mean': 150.0, // Typical teamwork score
        'stdDev': 50.0, // Typical standard deviation
      };
      
      // Cache the distribution
      await prefs.setString(cacheKey, jsonEncode({
        ...distribution,
        'updatedAt': DateTime.now().toIso8601String(),
      }));
      
      return distribution;
    } catch (e) {
      AppLogger.d('Error getting teamwork distribution: $e');
      return null;
    }
  }
  
  /// Normalize a value to a distribution
  static double _normalizeToDistribution(double value, double mean, double stdDev) {
    if (stdDev <= 0) return value;
    final zScore = (value - mean) / stdDev;
    return initialMu + zScore * beta;
  }
  
  /// Combine multiple TrueSkill ratings
  static Map<String, double> combineRatings(List<Map<String, double>> ratings) {
    if (ratings.isEmpty) {
      return {
        'mu': initialMu,
        'sigma': initialSigma,
      };
    }
    
    // Weighted average of mu values
    double totalWeight = 0.0;
    double weightedMu = 0.0;
    double minSigma = initialSigma;
    
    for (final rating in ratings) {
      final mu = rating['mu'] ?? initialMu;
      final sigma = rating['sigma'] ?? initialSigma;
      
      // Weight inversely proportional to uncertainty
      final weight = 1.0 / (sigma * sigma);
      totalWeight += weight;
      weightedMu += mu * weight;
      
      if (sigma < minSigma) {
        minSigma = sigma;
      }
    }
    
    final combinedMu = totalWeight > 0 ? weightedMu / totalWeight : initialMu;
    final combinedSigma = minSigma; // Use minimum uncertainty
    
    return {
      'mu': combinedMu.clamp(0.0, 50.0),
      'sigma': combinedSigma.clamp(1.0, initialSigma),
    };
  }
  
  /// Helper to safely convert to int
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
}

