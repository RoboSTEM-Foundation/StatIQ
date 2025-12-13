import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/utils/logger.dart';
import '../models/team.dart';
import '../services/vex_iq_scoring.dart';
import '../services/robotevents_api.dart';
import '../constants/app_constants.dart';

class VEXIQScoreCard extends StatefulWidget {
  final Team team;
  final bool showBreakdown;
  final int? seasonId;

  const VEXIQScoreCard({
    Key? key,
    required this.team,
    this.showBreakdown = false,
    this.seasonId,
  }) : super(key: key);

  @override
  _VEXIQScoreCardState createState() => _VEXIQScoreCardState();
}

class _VEXIQScoreCardState extends State<VEXIQScoreCard> {
  String? _vexIQScore;
  Map<String, dynamic>? _scoreBreakdown;
  bool _isLoading = true;
  String? _errorMessage;

  static const Duration _cacheTtl = Duration(days: 2);

  // Helper function to determine if a color is light (needs dark text)
  bool _isLightColor(Color color) {
    // Calculate relative luminance
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5;
  }

  // Get appropriate text color for tier based on background brightness
  Color _getTierTextColor(Color tierColor, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // For light tier colors (yellow, lime) on light backgrounds, use darker color
    if (!isDark && _isLightColor(tierColor)) {
      // Darken light colors for better contrast
      if (tierColor == const Color(0xFFFFEB3B) || tierColor == const Color(0xFFCDDC39)) {
        // Yellow and Lime - use darker version
        return const Color(0xFFF57F17); // Darker yellow/orange
      }
      // For other light colors, darken them
      return Color.fromRGBO(
        (tierColor.red * 0.6).round(),
        (tierColor.green * 0.6).round(),
        (tierColor.blue * 0.6).round(),
        1.0,
      );
    }
    
    // Default: use tier color as-is
    return tierColor;
  }

  String _cacheKey() {
    final season = widget.seasonId?.toString() ?? 'current';
    final identifier = widget.team.number.isNotEmpty
        ? widget.team.number
        : widget.team.id.toString();
    return 'statiq_score_${identifier}_$season';
  }

  @override
  void initState() {
    super.initState();
    _calculateScore();
  }

  @override
  void didUpdateWidget(VEXIQScoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate if team or season changed
    if (oldWidget.team.id != widget.team.id || oldWidget.seasonId != widget.seasonId) {
      _calculateScore();
    }
  }

  Future<void> _calculateScore() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cacheKey();
      final cachedString = prefs.getString(cacheKey);
      if (cachedString != null) {
        try {
          final cachedData = jsonDecode(cachedString) as Map<String, dynamic>;
          final updatedAtString = cachedData['updatedAt']?.toString();
          final updatedAt = updatedAtString != null ? DateTime.tryParse(updatedAtString) : null;
          final cachedBreakdown = cachedData['breakdown'];
          final needsBreakdown = widget.showBreakdown && cachedBreakdown == null;
          if (updatedAt != null && DateTime.now().difference(updatedAt) < _cacheTtl && !needsBreakdown) {
            final cachedScore = cachedData['score']?.toString();
            if (cachedScore != null && mounted) {
              setState(() {
                _vexIQScore = cachedScore;
                _scoreBreakdown = cachedBreakdown is Map<String, dynamic>
                    ? Map<String, dynamic>.from(cachedBreakdown)
                    : null;
                _isLoading = false;
              });
              return;
            }
          }
        } catch (e) {
          AppLogger.d('Error parsing statIQ score cache: $e');
        }
      }

      // Get comprehensive team data for scoring
      final teamData = await RobotEventsAPI.getComprehensiveTeamData(
        team: widget.team,
        seasonId: widget.seasonId,
      );

      // Calculate statIQ Score using the new system (now async)
      final score = await VEXIQScoring.calculateVEXIQScore(
        team: widget.team,
        worldSkillsData: teamData['worldSkills'],
        eventsData: teamData['events'],
        awardsData: teamData['awards'],
        rankingsData: teamData['rankings'],
        seasonId: teamData['seasonId'],
      );

      // Always load breakdown for info button (preload for faster dialog opening)
      Map<String, dynamic>? breakdown;
      breakdown = await VEXIQScoring.getScoreBreakdown(
        team: widget.team,
        worldSkillsData: teamData['worldSkills'],
        eventsData: teamData['events'],
        awardsData: teamData['awards'],
        rankingsData: teamData['rankings'],
        seasonId: teamData['seasonId'],
      );

      if (mounted) {
        setState(() {
          _vexIQScore = score;
          _scoreBreakdown = breakdown;
          _isLoading = false;
        });
      }

      // Cache result for future loads
      final cachePayload = <String, dynamic>{
        'score': score,
        'breakdown': breakdown,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(cacheKey, jsonEncode(cachePayload));
    } catch (e) {
      AppLogger.d('Error calculating statIQ Score: $e');
      
      // Fallback to basic scoring
      final basicScore = VEXIQScoring.calculateBasicScore(widget.team);
      
      if (mounted) {
        setState(() {
          _vexIQScore = basicScore;
          _errorMessage = 'Using basic calculation - some data unavailable';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.vexIQOrange.withOpacity(0.1),
              AppConstants.vexIQBlue.withOpacity(0.1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppConstants.spacingS),
            Text('Calculating statIQ Score...'),
          ],
        ),
      );
    }

    final score = double.tryParse(_vexIQScore ?? '0') ?? 0.0;
    final tier = VEXIQScoring.getPerformanceTier(score);
    final tierColor = VEXIQScoring.getTierColor(tier);
    final tierTextColor = _getTierTextColor(tierColor, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor.withOpacity(0.1),
            tierColor.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        border: Border.all(
          color: tierColor.withOpacity(0.3),
          width: 1,
        ),
        // Add white background for light tier colors to improve readability
        color: !isDark && _isLightColor(tierColor) 
            ? Colors.white.withOpacity(0.7) 
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tierColor,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                ),
                child: Text(
                  'statIQ Score',
                  style: AppConstants.caption.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: AppConstants.headline6.copyWith(
                  color: tierTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              InkWell(
                onTap: () => _showBreakdownDialog(context),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: !isDark && _isLightColor(tierColor)
                      ? Colors.white.withOpacity(0.8)
                      : tierColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                ),
                child: Text(
                  tier,
                  style: AppConstants.caption.copyWith(
                    color: tierTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(width: AppConstants.spacingS),
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
              ],
            ],
          ),
          if (widget.showBreakdown && _scoreBreakdown != null) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildInlineBreakdown(),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineBreakdown() {
    if (_scoreBreakdown == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Breakdown',
          style: AppConstants.bodyText1.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        _buildBreakdownItem(
          'World Skills Ranking',
          _scoreBreakdown!['worldSkillsRanking'],
        ),
        if (_scoreBreakdown!['trueskillRating']['score'] > 0)
          _buildBreakdownItem(
            'TrueSkill Rating',
            _scoreBreakdown!['trueskillRating'],
          ),
        _buildBreakdownItem(
          'Skills Score Quality',
          _scoreBreakdown!['skillsQuality'],
        ),
        if (_scoreBreakdown!['skillsBalance']['score'] > 0)
          _buildBreakdownItem(
            'Skills Balance Bonus',
            _scoreBreakdown!['skillsBalance'],
          ),
        _buildBreakdownItem(
          'Competition Performance',
          _scoreBreakdown!['competitionPerformance'],
        ),
        _buildBreakdownItem(
          'Award Excellence',
          _scoreBreakdown!['awardExcellence'],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingS),
          decoration: BoxDecoration(
            color: AppConstants.backgroundLight,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Score',
                style: AppConstants.bodyText1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_scoreBreakdown!['totalScore'].toStringAsFixed(1)} / ${_scoreBreakdown!['maxPossibleScore'].toStringAsFixed(1)}',
                style: AppConstants.bodyText1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: VEXIQScoring.getTierColor(
                    VEXIQScoring.getPerformanceTier(
                      _scoreBreakdown!['percentage'],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownItem(String title, Map<String, dynamic> data) {
    final score = data['score'] as double;
    final maxScore = data['maxScore'] as double;
    final description = data['description'] as String;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppConstants.bodyText2.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}',
                style: AppConstants.bodyText2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0,
            backgroundColor: ThemeUtils.getVeryMutedTextColor(context, opacity: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              AppConstants.vexIQOrange.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: AppConstants.caption.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
          if (data.containsKey('ranking') && data['ranking'] > 0) ...[
            Text(
              'Ranking: #${data['ranking']} out of ${data['totalTeams']} teams',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('combinedScore') && data['combinedScore'] > 0) ...[
            Text(
              'Combined Skills Score: ${data['combinedScore']}',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('eventCount') && data['eventCount'] > 0) ...[
            Text(
              'Competitions: ${data['eventCount']}',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('awardCount') && data['awardCount'] > 0) ...[
            Text(
              'Awards: ${data['awardCount']}',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('mu') && data['mu'] > 0) ...[
            const SizedBox(height: 2),
            Text(
              'TrueSkill μ: ${(data['mu'] as double).toStringAsFixed(2)}, σ: ${(data['sigma'] as double).toStringAsFixed(2)}',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('teamworkMatches') && data['teamworkMatches'] > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Teamwork Matches: ${data['teamworkMatches']}',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showBreakdownDialog(BuildContext context) async {
    // Show loading dialog first if breakdown not ready
    if (_scoreBreakdown == null && !_isLoading) {
      if (!mounted) return;
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppConstants.spacingM),
              Text('Loading breakdown...'),
            ],
          ),
        ),
      );
      
      try {
        final teamData = await RobotEventsAPI.getComprehensiveTeamData(
          team: widget.team,
          seasonId: widget.seasonId,
        );

        final breakdown = await VEXIQScoring.getScoreBreakdown(
          team: widget.team,
          worldSkillsData: teamData['worldSkills'],
          eventsData: teamData['events'],
          awardsData: teamData['awards'],
          rankingsData: teamData['rankings'],
          seasonId: teamData['seasonId'],
        );

        if (mounted) {
          setState(() {
            _scoreBreakdown = breakdown;
          });
          
          // Close loading dialog
          Navigator.of(context).pop();
          
          // Show breakdown dialog
          _showBreakdownContent(context);
        }
      } catch (e) {
        AppLogger.d('Error loading breakdown: $e');
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          // Show error dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to load breakdown: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } else if (_scoreBreakdown != null) {
      // Breakdown already loaded, show dialog immediately
      _showBreakdownContent(context);
    } else {
      // Still loading, show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppConstants.spacingM),
              Text('Loading breakdown...'),
            ],
          ),
        ),
      );
    }
  }
  
  void _showBreakdownContent(BuildContext context) {
    if (!mounted || _scoreBreakdown == null) return;
    
    final score = double.tryParse(_vexIQScore ?? '0') ?? 0.0;
    final tier = VEXIQScoring.getPerformanceTier(score);
    final tierColor = VEXIQScoring.getTierColor(tier);
    final tierTextColor = _getTierTextColor(tierColor, context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics, color: AppConstants.vexIQOrange),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              'statIQ Score Breakdown',
              style: AppConstants.headline6.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tierColor.withOpacity(0.1),
                      tierColor.withOpacity(0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Score',
                          style: AppConstants.bodyText2.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                        Text(
                          '${_scoreBreakdown!['totalScore'].toStringAsFixed(1)} / ${_scoreBreakdown!['maxPossibleScore'].toStringAsFixed(1)}',
                          style: AppConstants.headline6.copyWith(
                            fontWeight: FontWeight.bold,
                            color: tierTextColor,
                          ),
                        ),
                        Text(
                          '${_scoreBreakdown!['percentage'].toStringAsFixed(1)}% - $tier',
                          style: AppConstants.bodyText2.copyWith(
                            color: tierTextColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingM),
              _buildBreakdownItem(
                'World Skills Ranking',
                _scoreBreakdown!['worldSkillsRanking'],
              ),
              if (_scoreBreakdown!['trueskillRating']['score'] > 0)
                _buildBreakdownItem(
                  'TrueSkill Rating',
                  _scoreBreakdown!['trueskillRating'],
                ),
              _buildBreakdownItem(
                'Skills Score Quality',
                _scoreBreakdown!['skillsQuality'],
              ),
              if (_scoreBreakdown!['skillsBalance']['score'] > 0)
                _buildBreakdownItem(
                  'Skills Balance Bonus',
                  _scoreBreakdown!['skillsBalance'],
                ),
              _buildBreakdownItem(
                'Competition Performance',
                _scoreBreakdown!['competitionPerformance'],
              ),
              _buildBreakdownItem(
                'Award Excellence',
                _scoreBreakdown!['awardExcellence'],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 