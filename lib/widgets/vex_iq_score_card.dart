import 'package:flutter/material.dart';
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

      // Get score breakdown if needed
      Map<String, dynamic>? breakdown;
      if (widget.showBreakdown) {
        breakdown = await VEXIQScoring.getScoreBreakdown(
          team: widget.team,
          worldSkillsData: teamData['worldSkills'],
          eventsData: teamData['events'],
          awardsData: teamData['awards'],
          rankingsData: teamData['rankings'],
          seasonId: teamData['seasonId'],
        );
      }

      if (mounted) {
        setState(() {
          _vexIQScore = score;
          _scoreBreakdown = breakdown;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error calculating statIQ Score: $e');
      
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
            Text('Calculating statIQ Score™...'),
          ],
        ),
      );
    }

    final score = double.tryParse(_vexIQScore ?? '0') ?? 0.0;
    final tier = VEXIQScoring.getPerformanceTier(score, widget.team.grade);
    final tierColor = VEXIQScoring.getTierColor(tier);

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
                  'statIQ Score™',
                  style: AppConstants.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: AppConstants.headline6.copyWith(
                  color: tierColor,
                  fontWeight: FontWeight.bold,
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
                  color: tierColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                ),
                child: Text(
                  tier,
                  style: AppConstants.caption.copyWith(
                    color: tierColor,
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
            _buildScoreBreakdown(),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown() {
    if (_scoreBreakdown == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score Breakdown',
          style: AppConstants.bodyText1.copyWith(
            fontWeight: FontWeight.bold,
            color: AppConstants.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        _buildBreakdownItem(
          'World Skills Ranking',
          _scoreBreakdown!['worldSkillsRanking'],
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
                      widget.team.grade,
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
                  color: AppConstants.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0,
            backgroundColor: AppConstants.textSecondary.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              AppConstants.vexIQOrange.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: AppConstants.caption.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          if (data.containsKey('ranking') && data['ranking'] > 0) ...[
            Text(
              'Ranking: #${data['ranking']} out of ${data['totalTeams']} teams',
              style: AppConstants.caption.copyWith(
                color: AppConstants.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('combinedScore') && data['combinedScore'] > 0) ...[
            Text(
              'Combined Skills Score: ${data['combinedScore']}',
              style: AppConstants.caption.copyWith(
                color: AppConstants.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('eventCount') && data['eventCount'] > 0) ...[
            Text(
              'Competitions: ${data['eventCount']}',
              style: AppConstants.caption.copyWith(
                color: AppConstants.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (data.containsKey('awardCount') && data['awardCount'] > 0) ...[
            Text(
              'Awards: ${data['awardCount']}',
              style: AppConstants.caption.copyWith(
                color: AppConstants.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
} 