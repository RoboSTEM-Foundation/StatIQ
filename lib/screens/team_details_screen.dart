import 'package:flutter/material.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/widgets/vex_iq_score_card.dart';
import 'package:stat_iq/constants/app_constants.dart';
// import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/screens/event_details_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;

  const TeamDetailsScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Data lists
  List<Event> _teamEvents = [];
  List<dynamic> _teamAwards = [];
  List<Match> _teamMatches = [];
  List<TeamRanking> _teamRankings = [];
  List<TeamSkillsRanking> _teamSkillsRankings = [];
  
  // Loading states
  bool _isLoadingEvents = true;
  bool _isLoadingAwards = true;
  bool _isLoadingCompetitionData = true;
  
  // Season selection
  bool _usePreviousSeason = false;
  String _selectedSeason = 'Mix & Match (2025-2026)';
  int _selectedSeasonId = 196; // Mix & Match current season

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeamData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamData() async {
    await Future.wait([
      _loadTeamEvents(),
      _loadTeamAwards(),
      _loadCompetitionData(),
    ]);
  }

  Future<void> _loadTeamEvents() async {
    try {
      final events = await RobotEventsAPI.getTeamEvents(
        teamId: widget.team.id,
        seasonId: _selectedSeasonId,
      );
      if (mounted) {
        setState(() {
          _teamEvents = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      print('Error loading team events: $e');
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  Future<void> _loadTeamAwards() async {
    try {
      final awards = await RobotEventsAPI.getTeamAwards(
        teamId: widget.team.id,
        seasonId: _selectedSeasonId,
      );
      if (mounted) {
        setState(() {
          _teamAwards = awards;
          _isLoadingAwards = false;
        });
      }
    } catch (e) {
      print('Error loading team awards: $e');
      if (mounted) {
        setState(() {
          _isLoadingAwards = false;
        });
      }
    }
  }

  Future<void> _loadCompetitionData() async {
    try {
      // Load matches, rankings, and skills data
      // This would require additional API endpoints that may not be available
      if (mounted) {
        setState(() {
          _isLoadingCompetitionData = false;
        });
      }
    } catch (e) {
      print('Error loading competition data: $e');
      if (mounted) {
        setState(() {
          _isLoadingCompetitionData = false;
        });
      }
    }
  }

  void _onSeasonChanged(bool usePrevious) {
    setState(() {
      _usePreviousSeason = usePrevious;
      if (usePrevious) {
        _selectedSeason = 'Rapid Relay (2024-2025)';
        _selectedSeasonId = 189; // Rapid Relay season ID (has data)
      } else {
        _selectedSeason = 'Mix & Match (2025-2026)';
        _selectedSeasonId = 196; // Mix & Match season ID (current)
      }
      _isLoadingEvents = true;
      _isLoadingAwards = true;
      _isLoadingCompetitionData = true;
    });
    _loadTeamEvents();
    _loadTeamAwards();
    _loadCompetitionData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppConstants.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.team.number,
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.team.name.isNotEmpty)
              Text(
                widget.team.name,
                style: AppConstants.caption.copyWith(
                  color: AppConstants.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
          ],
        ),
        actions: [
          _buildSeasonSelector(),
          IconButton(
            icon: Icon(Icons.share, color: AppConstants.textPrimary),
            onPressed: () => _shareTeam(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppConstants.vexIQBlue,
          labelColor: AppConstants.vexIQBlue,
          unselectedLabelColor: AppConstants.textSecondary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Competitions'),
            Tab(text: 'Awards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildCompetitionsTab(),
          _buildAwardsTab(),
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    return PopupMenuButton<bool>(
      icon: Icon(Icons.calendar_today, color: AppConstants.textPrimary),
      tooltip: 'Select Season',
      onSelected: _onSeasonChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: false,
          child: Row(
            children: [
              Icon(
                Icons.fiber_new,
                color: _usePreviousSeason ? AppConstants.textSecondary : AppConstants.vexIQBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Mix & Match (2025-2026)',
                style: TextStyle(
                  color: _usePreviousSeason ? AppConstants.textSecondary : AppConstants.vexIQBlue,
                  fontWeight: _usePreviousSeason ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: _usePreviousSeason ? AppConstants.vexIQBlue : AppConstants.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Rapid Relay (2024-2025)',
                style: TextStyle(
                  color: _usePreviousSeason ? AppConstants.vexIQBlue : AppConstants.textSecondary,
                  fontWeight: _usePreviousSeason ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Info Card
          _buildTeamInfoCard(),
          const SizedBox(height: AppConstants.spacingM),
          
          // statIQ Score with Detailed Breakdown
          VEXIQScoreCard(
            team: widget.team,
            showBreakdown: false,
            seasonId: _selectedSeasonId,
          ),
          const SizedBox(height: AppConstants.spacingM),
          
          // Quick Stats
          _buildQuickStats(),
          const SizedBox(height: AppConstants.spacingM),
          
          // Season Selector Info
          _buildSeasonInfo(),
        ],
      ),
    );
  }

  Widget _buildTeamInfoCard() {
    return Card(
      elevation: AppConstants.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: AppConstants.vexIQBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.team.name.isNotEmpty ? widget.team.name : 'Team ${widget.team.number}',
                        style: AppConstants.headline6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if (widget.team.robotName.isNotEmpty)
                        Text(
                          'Robot: ${widget.team.robotName}',
                          style: AppConstants.bodyText2.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            _buildInfoRow(Icons.school, 'Organization', widget.team.organization),
            _buildInfoRow(Icons.location_on, 'Location', _getTeamLocation()),
            _buildInfoRow(Icons.grade, 'Grade Level', widget.team.grade),
            _buildInfoRow(
              widget.team.registered ? Icons.check_circle : Icons.radio_button_unchecked,
              'Registration Status',
              widget.team.registered ? 'Registered' : 'Not Registered',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppConstants.textSecondary,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Text(
            '$label: ',
            style: AppConstants.bodyText2.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyText2.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      elevation: AppConstants.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: AppConstants.headline6.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Competitions',
                    _teamEvents.length.toString(),
                    Icons.event,
                    AppConstants.vexIQBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Awards',
                    _teamAwards.length.toString(),
                    Icons.emoji_events,
                    AppConstants.vexIQOrange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Season',
                    _selectedSeason.split(' ').first,
                    Icons.calendar_today,
                    AppConstants.vexIQGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingS),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          value,
          style: AppConstants.headline6.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppConstants.caption.copyWith(
            color: AppConstants.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonInfo() {
    return Card(
      elevation: AppConstants.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _usePreviousSeason ? Icons.history : Icons.fiber_new,
                  color: AppConstants.vexIQBlue,
                  size: 20,
                ),
                const SizedBox(width: AppConstants.spacingS),
                            Expanded(
              child: Text(
                'Current Season: $_selectedSeason',
                style: AppConstants.bodyText1.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _usePreviousSeason
                  ? 'Viewing data from the previous Rapid Relay season. This was the 2024-2025 VEX IQ game.'
                  : 'Viewing data from the current Mix & Match season. This is the active 2025-2026 VEX IQ game.',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
              ),
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetitionsTab() {
    if (_isLoadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: AppConstants.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'No Competitions Found',
                style: AppConstants.headline6.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'This team hasn\'t participated in any VEX IQ competitions in the $_selectedSeason season yet.',
                style: AppConstants.bodyText2.copyWith(
                  color: AppConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _teamEvents.length,
      itemBuilder: (context, index) {
        final event = _teamEvents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          elevation: AppConstants.elevationS,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailsScreen(event: event),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spacingS),
                        decoration: BoxDecoration(
                          color: AppConstants.vexIQBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                        ),
                        child: Icon(
                          Icons.event,
                          color: AppConstants.vexIQBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Text(
                          event.name,
                          style: AppConstants.bodyText1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  if (_getEventLocation(event).isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppConstants.textSecondary,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: Text(
                            _getEventLocation(event),
                            style: AppConstants.bodyText2.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingS),
                  ],
                  if (event.start != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppConstants.textSecondary,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          '${event.start!.day}/${event.start!.month}/${event.start!.year}',
                          style: AppConstants.bodyText2.copyWith(
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  if (event.sku.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingS),
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 16,
                          color: AppConstants.textSecondary,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          event.sku,
                          style: AppConstants.caption.copyWith(
                            color: AppConstants.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAwardsTab() {
    if (_isLoadingAwards) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamAwards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: AppConstants.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'No Awards Found',
                style: AppConstants.headline6.copyWith(
                  color: AppConstants.textSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'This team hasn\'t won any awards in the $_selectedSeason season yet.',
                style: AppConstants.bodyText2.copyWith(
                  color: AppConstants.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _teamAwards.length,
      itemBuilder: (context, index) {
        final awardData = _teamAwards[index] as Map<String, dynamic>;
        final awardTitle = awardData['title'] as String? ?? 'Unknown Award';
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          elevation: AppConstants.elevationS,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingS),
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: AppConstants.vexIQOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Text(
                    awardTitle,
                    style: AppConstants.bodyText1.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTeamLocation() {
    final parts = <String>[];
    if (widget.team.city.isNotEmpty) parts.add(widget.team.city);
    if (widget.team.region.isNotEmpty) parts.add(widget.team.region);
    if (widget.team.country.isNotEmpty) parts.add(widget.team.country);
    return parts.join(', ');
  }

  String _getEventLocation(Event event) {
    if (event.location.isNotEmpty) {
      return event.location;
    }
    final parts = <String>[];
    if (event.city.isNotEmpty) parts.add(event.city);
    if (event.region.isNotEmpty) parts.add(event.region);
    if (event.country.isNotEmpty) parts.add(event.country);
    return parts.join(', ');
  }

  void _shareTeam() {
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${widget.team.number} - ${widget.team.name}'),
        backgroundColor: AppConstants.vexIQBlue,
      ),
    );
  }
} 