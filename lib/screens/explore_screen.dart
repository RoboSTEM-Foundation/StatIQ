import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/screens/event_details_screen.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/utils/theme_utils.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  bool _isLoadingSkills = true;
  List<dynamic> _skillsRankings = [];
  bool _isLoadingEvents = true;
  List<Event> _signatureEvents = [];

  @override
  void initState() {
    super.initState();
    _loadWorldSkillsRankings();
    _loadSignatureEvents();
  }

  Future<void> _loadWorldSkillsRankings() async {
    setState(() {
      _isLoadingSkills = true;
    });

    try {
      final rankings = await RobotEventsAPI.getWorldSkillsRankings();
      setState(() {
        _skillsRankings = rankings;
      });
    } catch (e) {
      print('Error loading world skills rankings: $e');
    } finally {
      setState(() {
        _isLoadingSkills = false;
      });
    }
  }

  Future<void> _loadSignatureEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      // Use proper API filtering with level[]=Signature parameter
      final events = await RobotEventsAPI.searchEvents(
        levels: ['Signature'],
      );
      
      // Filter for upcoming events and limit to 10
      final now = DateTime.now();
      final upcomingEvents = events
          .where((event) => event.start == null || event.start!.isAfter(now))
          .take(10)
          .toList();
      
      setState(() {
        _signatureEvents = upcomingEvents;
      });
    } catch (e) {
      print('Error loading signature events: $e');
    } finally {
      setState(() {
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _downloadSkillsCsv() async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloading skills data...')),
        );
      }
      
      // Download CSV data
      final csvContent = await RobotEventsAPI.downloadSkillsCsv(
        includePostSeason: false,
        gradeLevel: 'Middle School',
      );
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/skills_rankings_$timestamp.csv');
      await file.writeAsString(csvContent);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'VEX IQ Skills Rankings CSV',
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file ready to share!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading CSV: $e')),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadWorldSkillsRankings(),
      _loadSignatureEvents(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadSkillsCsv,
            tooltip: 'Download Skills CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: (_isLoadingSkills || _isLoadingEvents)
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      children: [
        _buildTopSkillsSection(),
        _buildSignatureEventsSection(),
      ],
    );
  }

  Widget _buildSignatureEventsSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Next 10 Signature Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_isLoadingEvents)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_signatureEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No upcoming signature events found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _signatureEvents.length,
              itemBuilder: (context, index) {
                final event = _signatureEvents[index];
                return _buildEventCard(event);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        title: Text(
          event.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (event.start != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatEventDate(event.start!),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: event),
            ),
          );
        },
      ),
    );
  }

  String _formatEventDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference > 0 && difference <= 7) {
      return 'In $difference days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _buildLocationString(Team team) {
    final parts = <String>[];
    if (team.city.isNotEmpty) parts.add(team.city);
    if (team.region.isNotEmpty) parts.add(team.region);
    if (team.country.isNotEmpty) parts.add(team.country);
    return parts.join(', ');
  }

  Widget _buildTopSkillsSection() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Top 10 World Skills',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _skillsRankings.length > 10 ? 10 : _skillsRankings.length,
            itemBuilder: (context, index) {
              final rank = _skillsRankings[index];
              final teamData = rank['team'];
              final scores = rank['scores'];
              if (teamData == null) {
                return const SizedBox.shrink(); // Skip if no team data
              }
              final team = Team.fromJson(teamData);
              final score = scores?['score'] ?? 0;
              
              // Debug logging to see what data we have
              print('🔍 Skills Team Debug: ${team.number} - Name: "${team.name}" - Organization: "${team.organization}"');
              print('🔍 Skills Team Data: $teamData');
              print('🔍 Team Number Debug: team.number = "${team.number}", isEmpty = ${team.number.isEmpty}');
              print('🔍 Raw team data number field: ${teamData['team']} vs ${teamData['number']}');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppConstants.vexIQBlue,
                    child: Text(
                      '${rank['rank'] ?? index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    team.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (team.name.isNotEmpty) ...[
                        Text(
                          team.name,
                          style: TextStyle(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                      ] else if (team.organization.isNotEmpty) ...[
                        Text(
                          team.organization,
                          style: TextStyle(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                      if (team.city.isNotEmpty || team.region.isNotEmpty || team.country.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _buildLocationString(team),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Score: $score',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (scores != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'P: ${scores['programming'] ?? 0} | D: ${scores['driver'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeamDetailsScreen(team: team),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
