import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';

class EventLevelSelectScreen extends StatefulWidget {
  final List<String> selectedLevels;
  
  const EventLevelSelectScreen({
    super.key,
    required this.selectedLevels,
  });

  @override
  State<EventLevelSelectScreen> createState() => _EventLevelSelectScreenState();
}

class _EventLevelSelectScreenState extends State<EventLevelSelectScreen> {
  late List<String> _selectedLevels;

  @override
  void initState() {
    super.initState();
    _selectedLevels = List.from(widget.selectedLevels);
  }

  @override
  Widget build(BuildContext context) {
    final allLevels = ApiConfig.availableEventLevels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Event Levels'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: allLevels.length,
        itemBuilder: (context, index) {
          final level = allLevels[index];
          final isSelected = _selectedLevels.contains(level);
          
          return CheckboxListTile(
            title: Text(level),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedLevels.add(level);
                } else {
                  _selectedLevels.remove(level);
                }
              });
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pop(_selectedLevels);
        },
        backgroundColor: AppConstants.vexIQOrange,
        icon: const Icon(Icons.check),
        label: Text('Apply (${_selectedLevels.length})'),
      ),
    );
  }
}

