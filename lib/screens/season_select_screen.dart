import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';

class SeasonSelectScreen extends StatelessWidget {
  final String selectedSeason;
  final int selectedSeasonId;
  
  const SeasonSelectScreen({
    super.key,
    required this.selectedSeason,
    required this.selectedSeasonId,
  });

  @override
  Widget build(BuildContext context) {
    final seasons = ApiConfig.availableSeasons.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Season'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: seasons.length,
        itemBuilder: (context, index) {
          final season = seasons[index];
          final seasonId = season.value['vexiq'] as int;
          final isSelected = seasonId == selectedSeasonId;
          
          return RadioListTile<String>(
            title: Text(season.key),
            value: season.key,
            groupValue: selectedSeason,
            onChanged: (value) {
              Navigator.of(context).pop({
                'name': season.key,
                'id': seasonId,
              });
            },
            secondary: isSelected ? const Icon(Icons.check, color: AppConstants.vexIQOrange) : null,
          );
        },
      ),
    );
  }
}

