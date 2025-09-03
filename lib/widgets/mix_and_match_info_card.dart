import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:url_launcher/url_launcher.dart';

class MixAndMatchInfoCard extends StatelessWidget {
  const MixAndMatchInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppConstants.elevationM,
      margin: const EdgeInsets.all(AppConstants.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.vexIQOrange.withOpacity(0.1),
              AppConstants.vexIQRed.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppConstants.spacingL),
            _buildGameOverview(),
            const SizedBox(height: AppConstants.spacingL),
            _buildScoringElements(),
            const SizedBox(height: AppConstants.spacingL),
            _buildSeasonInfo(),
            const SizedBox(height: AppConstants.spacingL),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppConstants.vexIQOrange, AppConstants.vexIQRed],
            ),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          ),
          child: Icon(
            Icons.sports_esports,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VEX IQ Challenge',
                style: AppConstants.headline6.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              Text(
                'Mix and Match',
                style: AppConstants.headline3.copyWith(
                  color: AppConstants.vexIQOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '2025-2026 Season',
                style: AppConstants.bodyText2.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          decoration: BoxDecoration(
            color: AppConstants.vexIQGreen,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          ),
          child: Text(
            'CURRENT',
            style: AppConstants.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverview() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        border: Border.all(
          color: AppConstants.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppConstants.vexIQBlue,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                'Game Overview',
                style: AppConstants.headline6.copyWith(
                  color: AppConstants.vexIQBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'In Mix and Match, teams work together to score points by placing colored balls into goals, clearing balls from the field, and positioning their robots strategically. The game emphasizes teamwork, strategy, and precision.',
            style: AppConstants.bodyText1,
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              _buildGameStat('Match Duration', '60 seconds'),
              const SizedBox(width: AppConstants.spacingL),
              _buildGameStat('Autonomous', '15 seconds'),
              const SizedBox(width: AppConstants.spacingL),
              _buildGameStat('Driver Control', '45 seconds'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppConstants.headline6.copyWith(
            color: AppConstants.vexIQOrange,
          ),
        ),
        Text(
          label,
          style: AppConstants.caption,
        ),
      ],
    );
  }

  Widget _buildScoringElements() {
    final scoringElements = [
      {'title': 'High Goal', 'points': '3 pts', 'icon': Icons.keyboard_arrow_up, 'color': AppConstants.vexIQRed},
      {'title': 'Low Goal', 'points': '1 pt', 'icon': Icons.keyboard_arrow_down, 'color': AppConstants.vexIQBlue},
      {'title': 'Ball Cleared', 'points': '2 pts', 'icon': Icons.clear_all, 'color': AppConstants.vexIQGreen},
      {'title': 'Robot Parked', 'points': '5 pts', 'icon': Icons.local_parking, 'color': AppConstants.vexIQOrange},
      {'title': 'Platform', 'points': '10 pts', 'icon': Icons.height, 'color': AppConstants.vexIQYellow},
      {'title': 'Hanging', 'points': '15 pts', 'icon': Icons.vertical_align_top, 'color': Colors.purple},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scoring Elements',
          style: AppConstants.headline6,
        ),
        const SizedBox(height: AppConstants.spacingM),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: AppConstants.spacingM,
            mainAxisSpacing: AppConstants.spacingS,
          ),
          itemCount: scoringElements.length,
          itemBuilder: (context, index) {
            final element = scoringElements[index];
            return Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: (element['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                border: Border.all(
                  color: (element['color'] as Color).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    element['icon'] as IconData,
                    color: element['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          element['title'] as String,
                          style: AppConstants.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          element['points'] as String,
                          style: AppConstants.caption.copyWith(
                            color: element['color'] as Color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSeasonInfo() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.vexIQBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        border: Border.all(
          color: AppConstants.vexIQBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: AppConstants.vexIQBlue,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                'Season Information',
                style: AppConstants.headline6.copyWith(
                  color: AppConstants.vexIQBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          _buildSeasonInfoRow('Season', ApiConfig.currentSeasonName),
          _buildSeasonInfoRow('Game', ApiConfig.currentGameName),
          _buildSeasonInfoRow('Program ID', ApiConfig.vexIQProgramId.toString()),
          _buildSeasonInfoRow('ES Season ID', ApiConfig.vexIQSeasonIds['Elementary School'].toString()),
          _buildSeasonInfoRow('MS Season ID', ApiConfig.vexIQSeasonIds['Middle School'].toString()),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Note: Season IDs will be updated when officially announced by VEX Robotics.',
            style: AppConstants.caption.copyWith(
              fontStyle: FontStyle.italic,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppConstants.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: AppConstants.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _launchGameManual(),
            icon: const Icon(Icons.menu_book),
            label: const Text('Game Manual'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.vexIQBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _launchVEXIQWebsite(),
            icon: const Icon(Icons.language),
            label: const Text('VEX IQ Site'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.vexIQGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchGameManual() async {
    final Uri url = Uri.parse('https://www.vexrobotics.com/iq/competition/vexiq-challenge/game');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchVEXIQWebsite() async {
    final Uri url = Uri.parse('https://www.vexrobotics.com/iq');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
} 