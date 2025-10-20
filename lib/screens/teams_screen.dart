import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/widgets/optimized_team_search_widget.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Teams'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
              elevation: 0,
        centerTitle: true,
      ),
      body: const OptimizedTeamSearchWidget(
        hintText: 'Search 26,000+ teams by number (e.g., 2A, 14G)...',
        showSyncStatus: true,
      ),
    );
  }
}