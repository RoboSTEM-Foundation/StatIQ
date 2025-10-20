import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/widgets/optimized_team_search_widget.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Teams'),
        backgroundColor: AppConstants.backgroundColor,
        foregroundColor: AppConstants.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: const Column(
        children: [
          OptimizedTeamSearchWidget(
            hintText: 'Search teams by number, name, or location...',
            showSyncStatus: true,
          ),
        ],
      ),
    );
  }
}