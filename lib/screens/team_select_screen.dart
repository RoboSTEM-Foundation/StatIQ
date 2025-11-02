import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/widgets/optimized_team_search_widget.dart';

class TeamSelectScreen extends StatelessWidget {
  const TeamSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Team'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: OptimizedTeamSearchWidget(
          isSelectionMode: true,
          showSyncStatus: true,
          onTeamSelected: (team) async {
            final settings = Provider.of<UserSettings>(context, listen: false);
            await settings.setMyTeam(team.number);
            await settings.addFavoriteTeam(team.number);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}


