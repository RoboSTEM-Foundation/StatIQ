import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/widgets/optimized_team_search_widget.dart';
import 'package:stat_iq/widgets/simple_team_search_widget.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  bool _showFullList = false;

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Text('Show full list of teams'),
                    SizedBox(width: 8),
                    Chip(label: Text('BETA'), backgroundColor: Color(0xFFE3F2FD)),
                  ],
                ),
                Switch(
                  value: _showFullList,
                  onChanged: (v) => setState(() => _showFullList = v),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: _showFullList
                ? const OptimizedTeamSearchWidget(
                    hintText: 'Search teams by number, name, or location (Ex: China, 839a, Magikid)',
                    showSyncStatus: true,
                  )
                : const SimpleTeamSearchWidget(
        hintText: 'Search teams by number, name, or location (Ex: China, 839a, Magikid)',
        showSyncStatus: true,
                    useAPI: true,
                  ),
          ),
        ],
      ),
    );
  }
}