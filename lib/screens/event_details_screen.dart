import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/event.dart';
import '../models/team.dart';
import '../services/robotevents_api.dart';
import '../services/user_settings.dart';
import '../services/optimized_team_search.dart';
import '../services/team_sync_service.dart';
import '../services/notification_service.dart';
import '../constants/app_constants.dart';
import '../utils/theme_utils.dart';
import '../widgets/optimized_team_search_widget.dart';
import '../widgets/simple_team_search_widget.dart';
import 'team_details_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Data loading states
  bool _isLoadingTeams = true;
  bool _isLoadingMatches = true;
  bool _isLoadingSkills = true;
  bool _isLoadingDivisions = true;
  bool _isLoadingAwards = true;
  
  // Data
  List<Team> _teams = [];
  Map<int, List<dynamic>> _matchesByDivision = {};
  Map<int, List<dynamic>> _rankingsByDivision = {};
  List<dynamic> _skills = [];
  List<dynamic> _divisions = [];
  List<dynamic> _awards = [];
  int? _selectedDivisionId;
  
  // Error states
  String? _teamsError;
  String? _matchesError;
  String? _rankingsError;
  String? _skillsError;
  String? _divisionsError;
  String? _awardsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Combined rankings and results
    _loadEventData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEventData() async {
    // Load event details first to get divisions
    await _loadEventDivisions();
    
    // Then load other data in parallel, but ensure divisions are loaded first
    if (_divisions.isNotEmpty) {
    await Future.wait([
      _loadEventTeams(),
      _loadEventSkills(),
      _loadEventMatchesForAllDivisions(),
        _loadEventRankingsForAllDivisions(),
        _loadEventAwards(),
      ]);
    } else {
      // If no divisions, still load other data
      await Future.wait([
        _loadEventTeams(),
        _loadEventSkills(),
        _loadEventAwards(),
      ]);
    }
  }

  Future<void> _loadEventTeams() async {
    try {
      setState(() {
        _isLoadingTeams = true;
        _teamsError = null;
      });

      final teams = await RobotEventsAPI.getEventTeams(eventId: widget.event.id);
      
      if (mounted) {
        setState(() {
          _teams = teams;
          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _teamsError = 'Error loading teams: ${e.toString()}';
          _isLoadingTeams = false;
        });
      }
    }
  }

  Future<void> _loadEventMatchesForAllDivisions() async {
    try {
      setState(() {
        _isLoadingMatches = true;
        _matchesError = null;
      });

      // Load matches for all divisions in parallel
      final matchesFutures = _divisions.map((division) async {
        try {
          final divisionId = division['id'] as int;
          final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
          
          final divisionMatches = await RobotEventsAPI.getEventMatches(
            eventId: widget.event.id,
            divisionId: divisionId,
          );
          
          print('Loaded ${divisionMatches.length} matches for division: $divisionName');
          return MapEntry(divisionId, divisionMatches);
        } catch (e) {
          print('Error loading matches for division ${division['id']}: $e');
          return MapEntry(division['id'] as int, <dynamic>[]);
        }
      });

      // Wait for all division matches to load in parallel
      final matchesResults = await Future.wait(matchesFutures);
      final matchesByDivision = Map<int, List<dynamic>>.fromEntries(matchesResults);
      
      if (mounted) {
        setState(() {
          _matchesByDivision = matchesByDivision;
          _isLoadingMatches = false;
          
          // Set default division if we have divisions
          if (_divisions.isNotEmpty && _selectedDivisionId == null) {
            _selectedDivisionId = _divisions.first['id'] as int;
          }
        });
        
        // Schedule notifications for future matches with the user's team
        await _scheduleEventNotifications(matchesByDivision);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _matchesError = 'Error loading matches: ${e.toString()}';
          _isLoadingMatches = false;
        });
      }
    }
  }

  Future<void> _loadEventSkills() async {
    try {
      setState(() {
        _isLoadingSkills = true;
        _skillsError = null;
      });

      final skills = await RobotEventsAPI.getEventSkills(eventId: widget.event.id);
      
      if (mounted) {
        setState(() {
          _skills = skills;
          _isLoadingSkills = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _skillsError = 'Error loading skills: ${e.toString()}';
          _isLoadingSkills = false;
        });
      }
    }
  }

  Future<void> _loadEventAwards() async {
    try {
      setState(() {
        _isLoadingAwards = true;
        _awardsError = null;
      });

      final awards = await RobotEventsAPI.getEventAwards(eventId: widget.event.id);
      
      if (mounted) {
        setState(() {
          _awards = awards;
          _isLoadingAwards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _awardsError = 'Error loading awards: ${e.toString()}';
          _isLoadingAwards = false;
        });
      }
    }
  }

  Future<void> _loadEventRankingsForAllDivisions() async {
    try {
      setState(() {
        _rankingsError = null;
      });

      // Load rankings for all divisions in parallel
      final rankingsFutures = _divisions.map((division) async {
        try {
          final divisionId = division['id'] as int;
          final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
          
          final divisionRankings = await RobotEventsAPI.getEventDivisionRankings(
            eventId: widget.event.id,
            divisionId: divisionId,
          );
          
          print('Loaded ${divisionRankings.length} rankings for division: $divisionName');
          return MapEntry(divisionId, divisionRankings);
        } catch (e) {
          print('Error loading rankings for division ${division['id']}: $e');
          return MapEntry(division['id'] as int, <dynamic>[]);
        }
      });

      // Wait for all division rankings to load in parallel
      final rankingsResults = await Future.wait(rankingsFutures);
      final rankingsByDivision = Map<int, List<dynamic>>.fromEntries(rankingsResults);
      
      if (mounted) {
        setState(() {
          _rankingsByDivision = rankingsByDivision;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rankingsError = 'Error loading rankings: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadEventDivisions() async {
    try {
      setState(() {
        _isLoadingDivisions = true;
        _divisionsError = null;
      });

      final divisions = await RobotEventsAPI.getEventDivisions(eventId: widget.event.id);
      
      if (mounted) {
        setState(() {
          _divisions = divisions;
          _isLoadingDivisions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _divisionsError = 'Error loading divisions: ${e.toString()}';
          _isLoadingDivisions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.name),
        elevation: 0,
        actions: [
          // Share button
          IconButton(
              icon: Icon(
                Icons.share,
                color: Theme.of(context).iconTheme.color,
              ),
            onPressed: _shareEvent,
            tooltip: 'Share Event',
          ),
          // Favorite button
          Consumer<UserSettings>(
            builder: (context, settings, child) {
              final isFavorite = settings.isFavoriteEvent(widget.event.sku);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Theme.of(context).iconTheme.color,
                ),
                onPressed: () async {
                  if (isFavorite) {
                    await settings.removeFavoriteEvent(widget.event.sku);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${widget.event.name} removed from favorites')),
                      );
                    }
                  } else {
                    await settings.addFavoriteEvent(widget.event.sku);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${widget.event.name} added to favorites')),
                      );
                    }
                  }
                },
                tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.vexIQOrange,
          unselectedLabelColor: ThemeUtils.getSecondaryTextColor(context, opacity: 0.6),
          indicatorColor: AppConstants.vexIQOrange,
          tabs: const [
            Tab(text: 'Info', icon: Icon(Icons.info_outline)),
            Tab(text: 'Teams', icon: Icon(Icons.people)),
            Tab(text: 'Tournament', icon: Icon(Icons.schedule)),
            Tab(text: 'Results', icon: Icon(Icons.leaderboard)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildTeamsTab(),
          _buildTournamentTab(),
          _buildCombinedResultsTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final hasLocation = widget.event.city.isNotEmpty ||
        widget.event.region.isNotEmpty ||
        widget.event.country.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventInfoCard(),
          if (hasLocation) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildLocationCard(),
          ],
          const SizedBox(height: AppConstants.spacingM),
          _buildStatIQScoreCard(),
        ],
      ),
    );
  }

  Widget _buildEventInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event,
                  color: AppConstants.vexIQOrange,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Event Information',
                  style: AppConstants.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            _buildInfoRow('Event Name', widget.event.name),
            _buildInfoRow('Event Code', widget.event.sku),
            _buildInfoRow('Season', 'Mix & Match (2025-2026)'),
            _buildInfoRow('Program', 'VEX IQ'),
            if (widget.event.start != null)
              _buildInfoRow('Start Date', _formatDate(widget.event.start!)),
            if (widget.event.end != null)
              _buildInfoRow('End Date', _formatDate(widget.event.end!)),
            if (widget.event.levelClassName.isNotEmpty)
              _buildInfoRow('Level', widget.event.levelClassName),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final hasLocation = widget.event.city.isNotEmpty || 
                       widget.event.region.isNotEmpty || 
                       widget.event.country.isNotEmpty;
    
    if (!hasLocation) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: AppConstants.vexIQBlue,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Location',
                  style: AppConstants.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            if (widget.event.city.isNotEmpty)
              _buildInfoRow('City', widget.event.city),
            if (widget.event.region.isNotEmpty)
              _buildInfoRow('Region', widget.event.region),
            if (widget.event.country.isNotEmpty)
              _buildInfoRow('Country', widget.event.country),
          ],
        ),
      ),
    );
  }

  Widget _buildDivisionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group_work,
                  color: AppConstants.vexIQGreen,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Divisions',
                  style: AppConstants.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            if (_isLoadingDivisions)
              const Center(child: CircularProgressIndicator())
            else if (_divisionsError != null)
              Text(
                _divisionsError!,
                style: AppConstants.bodyText2.copyWith(color: Colors.red),
              )
            else if (_divisions.isEmpty)
              Text(
                'No divisions information available',
                style: AppConstants.bodyText2.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              )
            else
              Column(
                children: _divisions.map((division) {
                  final name = division['name'] ?? 'Unknown Division';
                  final id = division['id'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppConstants.vexIQOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Flexible(
                          child: Text(
                            name,
                            style: AppConstants.bodyText1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Removed ID display to clean up the interface
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppConstants.vexIQYellow,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Quick Stats',
                  style: AppConstants.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Skills Rank in World',
                    _isLoadingSkills ? '...' : '${_getWorldSkillRank()} (${_getWorldSkillsCombinedPts()})',
                    Icons.public,
                    AppConstants.vexIQBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Skills Rank in Region',
                    _isLoadingSkills ? '...' : _getRegionSkillRank().toString(),
                    Icons.location_on,
                    AppConstants.vexIQGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Amount of Awards',
                    _isLoadingAwards ? '...' : _awards.length.toString(),
                    Icons.emoji_events,
                    AppConstants.vexIQOrange,
                  ),
                ),
                const Expanded(child: SizedBox()), // Empty space for layout
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingS),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppConstants.headline6.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppConstants.caption.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatIQScoreCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppConstants.vexIQOrange,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'StatIQ Score',
                  style: AppConstants.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppConstants.vexIQOrange.withOpacity(0.1),
                    AppConstants.vexIQBlue.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                border: Border.all(
                  color: AppConstants.vexIQOrange.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Event Performance Score',
                    style: AppConstants.bodyText1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    _calculateEventStatIQScore().toStringAsFixed(1),
                    style: AppConstants.headline3.copyWith(
                      color: AppConstants.vexIQOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Based on team performance, skills rankings, and competition level',
                    style: AppConstants.caption.copyWith(
                      color: ThemeUtils.getSecondaryTextColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  double _calculateEventStatIQScore() {
    if (_teams.isEmpty && _skills.isEmpty) return 0.0;
    
    double score = 0.0;
    
    // Factor 1: Team count (max 20 points)
    final teamCount = _teams.length;
    if (teamCount > 0) {
      score += (teamCount / 50.0 * 20.0).clamp(0.0, 20.0);
    }
    
    // Factor 2: Skills performance (max 30 points)
    if (_skills.isNotEmpty) {
      int bestScore = 0;
      for (final skill in _skills) {
        final skillScore = (skill['score'] is int) ? skill['score'] as int : int.tryParse(skill['score']?.toString() ?? '0') ?? 0;
        if (skillScore > bestScore) {
          bestScore = skillScore;
        }
      }
      score += (bestScore / 200.0 * 30.0).clamp(0.0, 30.0);
    }
    
    // Factor 3: Competition level (max 25 points)
    final eventName = widget.event.name.toLowerCase();
    if (eventName.contains('worlds') || eventName.contains('championship')) {
      score += 25.0;
    } else if (eventName.contains('signature')) {
      score += 20.0;
    } else if (eventName.contains('regional') || eventName.contains('state')) {
      score += 15.0;
    } else {
      score += 10.0;
    }
    
    // Factor 4: Awards (max 25 points)
    final awardCount = _awards.length;
    score += (awardCount / 10.0 * 25.0).clamp(0.0, 25.0);
    
    return score.clamp(0.0, 100.0);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppConstants.bodyText2.copyWith(
                fontWeight: FontWeight.w600,
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: Text(
              value,
              style: AppConstants.bodyText1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsTab() {
    if (_isLoadingTeams) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading Teams',
              style: AppConstants.headline6,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _teamsError!,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Teams Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This event has no registered teams yet',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        final userSettings = Provider.of<UserSettings>(context, listen: false);
        final isMyTeam = userSettings.myTeam == team.number;

        return Card(
          color: isMyTeam ? AppConstants.vexIQBlue.withOpacity(0.1) : null,
          shape: isMyTeam
              ? RoundedRectangleBorder(
                  side: const BorderSide(color: AppConstants.vexIQBlue, width: 2),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                )
              : null,
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConstants.vexIQOrange,
              child: Text(
                team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
                style: AppConstants.bodyText2.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(team.number),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (team.name.isNotEmpty) Text(team.name),
                if (team.organization.isNotEmpty) 
                  Text(
                    team.organization,
                    style: AppConstants.caption,
                  ),
              ],
            ),
            trailing: Consumer<UserSettings>(
              builder: (context, settings, child) {
                final isFavorite = settings.isFavoriteTeam(team.number);
                return IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () async {
                    if (isFavorite) {
                      await settings.removeFavoriteTeam(team.number);
                    } else {
                      await settings.addFavoriteTeam(team.number);
                    }
                  },
                );
              },
            ),
            onTap: () {
              // Navigate to team details with event context (Bug Patch 3 requirement)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamDetailsScreen(
                    team: team,
                    eventId: widget.event.id, // Pass event ID to filter matches
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMatchesTab() {
    return Column(
      children: [
        // Division selector header (like Elapse app)
        if (_divisions.isNotEmpty) 
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.group_work, color: AppConstants.vexIQOrange),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Division:',
                  style: AppConstants.bodyText1.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedDivisionId,
                    isExpanded: true,
                    hint: Text('Select Division'),
                    items: _divisions.map<DropdownMenuItem<int>>((division) {
                      final divisionId = division['id'] as int;
                      final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
                      final matchCount = _matchesByDivision[divisionId]?.length ?? 0;
                      
                      return DropdownMenuItem<int>(
                        value: divisionId,
                        child: Text('$divisionName ($matchCount matches)'),
                      );
                    }).toList(),
                    onChanged: (int? newDivisionId) {
                      setState(() {
                        _selectedDivisionId = newDivisionId;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        
        // Matches content
        Expanded(
          child: _buildMatchesContent(),
        ),
      ],
    );
  }

  Widget _buildMatchesContent() {
    if (_isLoadingMatches) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_matchesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading Matches',
              style: AppConstants.headline6,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _matchesError!,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No divisions available
    if (_divisions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Divisions Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This event does not have division information available',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No division selected
    if (_selectedDivisionId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Select a Division',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Choose a division from the dropdown above to view matches',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Get matches for selected division
    final selectedMatches = _matchesByDivision[_selectedDivisionId] ?? [];
    
    if (selectedMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports_outlined,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Matches Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No matches available for the selected division',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Display matches for selected division
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: selectedMatches.length,
      itemBuilder: (context, index) {
        return _buildMatchCard(context, selectedMatches[index]);
      },
    );
  }

  // Tournament tab implementation with match scheduling and alliance colors
  Widget _buildTournamentTab() {
    return Column(
        children: [
        // Team notification header
          Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
            color: AppConstants.vexIQGreen.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Consumer<UserSettings>(
            builder: (context, settings, child) {
              if (settings.myTeam != null && settings.notificationsEnabled) {
                // Show configured notifications with next 5 matches
                final nextMatches = _getNext5MatchesForTeam(settings.myTeam!);
                return Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active, color: AppConstants.vexIQGreen),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Team ${settings.myTeam} Notifications',
                                style: AppConstants.bodyText1.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.vexIQGreen,
                                ),
                              ),
                              Text(
                                '${settings.notificationMinutesBefore}m before each match',
                                style: AppConstants.caption.copyWith(
                                  color: ThemeUtils.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showTeamNotificationDialog(),
                          color: AppConstants.vexIQGreen,
                        ),
                      ],
                    ),
                    if (nextMatches.isNotEmpty) ...[
                      const Divider(height: 20),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: nextMatches.length,
                          itemBuilder: (context, index) {
                            final match = nextMatches[index];
                            return _buildNextMatchChip(match);
                          },
                        ),
                      ),
                    ],
                  ],
                );
              } else {
                // Show add team button
                return Row(
                  children: [
                    Icon(Icons.notifications_active, color: AppConstants.vexIQGreen),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Team Notifications',
                            style: AppConstants.bodyText1.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppConstants.vexIQGreen,
                            ),
                          ),
                          Text(
                            'Get notified before your team\'s matches',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showTeamNotificationDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Team'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.vexIQGreen,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingM,
                          vertical: AppConstants.spacingS,
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
        
                // Division selector header
        if (_divisions.isNotEmpty) 
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppConstants.vexIQOrange),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  'Division:',
                  style: AppConstants.bodyText1.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedDivisionId,
                    isExpanded: true,
                    hint: Text('Select Division'),
                    items: _divisions.map<DropdownMenuItem<int>>((division) {
                      final divisionId = division['id'] as int;
                      final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
                      final matchCount = _matchesByDivision[divisionId]?.length ?? 0;
                      
                      return DropdownMenuItem<int>(
                        value: divisionId,
                        child: Text('$divisionName ($matchCount matches)'),
                      );
                    }).toList(),
                    onChanged: (int? newDivisionId) {
                      setState(() {
                        _selectedDivisionId = newDivisionId;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        
        // Tournament content with matches
        Expanded(
          child: _buildTournamentContent(),
        ),
      ],
    );
  }

  Widget _buildTournamentContent() {
    if (_selectedDivisionId == null) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              Icons.schedule_outlined,
            size: 64,
            color: ThemeUtils.getVeryMutedTextColor(context),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
              'Select a Division',
            style: AppConstants.headline6.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
              'Choose a division to view match schedules',
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

    // Get matches for selected division
    final selectedMatches = _matchesByDivision[_selectedDivisionId] ?? [];
    
    if (selectedMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Matches Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No matches available for the selected division',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

    // Group matches by status (VRC RoboScout pattern)
    final Map<String, List<dynamic>> matchesByGroup = {};
    final List<dynamic> upcomingMatches = [];
    final List<dynamic> pastMatches = [];
    final List<dynamic> noTimeMatches = [];
    
    for (final match in selectedMatches) {
      final scheduledTime = match['scheduled']?.toString() ?? '';
      final startedTime = match['started']?.toString() ?? '';
      final finishedTime = match['finished']?.toString() ?? '';
      
      DateTime? matchDateTime;
      String timeToUse = '';
      
      // Prioritize times like VRC RoboScout: started > scheduled > finished
      if (startedTime.isNotEmpty) {
        timeToUse = startedTime;
      } else if (scheduledTime.isNotEmpty) {
        timeToUse = scheduledTime;
      } else if (finishedTime.isNotEmpty) {
        timeToUse = finishedTime;
      }
      
      if (timeToUse.isNotEmpty) {
        try {
          // Parse as UTC and convert to local timezone
          final utcDateTime = DateTime.parse(timeToUse);
          matchDateTime = utcDateTime.toLocal();
          
          final now = DateTime.now();
          if (matchDateTime.isAfter(now)) {
            upcomingMatches.add(match);
          } else {
            pastMatches.add(match);
          }
        } catch (e) {
          print('Error parsing match time: $e');
          noTimeMatches.add(match);
        }
      } else {
        noTimeMatches.add(match);
      }
    }
    
    // Add groups to the map
    if (upcomingMatches.isNotEmpty) {
      matchesByGroup['Upcoming Matches'] = upcomingMatches;
    }
    if (pastMatches.isNotEmpty) {
      matchesByGroup['Past Matches'] = pastMatches;
    }
    if (noTimeMatches.isNotEmpty) {
      matchesByGroup['Matches (No Time Data)'] = noTimeMatches;
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: matchesByGroup.length,
      itemBuilder: (context, index) {
        final groupName = matchesByGroup.keys.elementAt(index);
        final matchesForGroup = matchesByGroup[groupName]!;
        
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // Group header
          Container(
              width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
              margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
            decoration: BoxDecoration(
              color: groupName.contains('Upcoming')
                  ? AppConstants.vexIQGreen.withOpacity(0.06)
                  : groupName.contains('Past')
                      ? AppConstants.vexIQOrange.withOpacity(0.06)
                      : ThemeUtils.getVeryMutedTextColor(context, opacity: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ThemeUtils.getSecondaryTextColor(context).withOpacity(0.08),
              ),
            ),
              child: Row(
                children: [
                  Icon(
                    groupName.contains('Upcoming') 
                        ? Icons.schedule
                        : groupName.contains('Past')
                            ? Icons.history
                            : Icons.help_outline,
                    color: groupName.contains('Upcoming') 
                        ? AppConstants.vexIQGreen
                        : groupName.contains('Past')
                            ? AppConstants.vexIQOrange
                            : ThemeUtils.getSecondaryTextColor(context),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Expanded(
                    child: Text(
                      groupName,
                      style: AppConstants.bodyText1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: groupName.contains('Upcoming') 
                            ? AppConstants.vexIQGreen
                            : groupName.contains('Past')
                                ? AppConstants.vexIQOrange
                                : ThemeUtils.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                  Text(
                    '${matchesForGroup.length} matches',
                    style: AppConstants.caption.copyWith(
                      color: ThemeUtils.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            
            // Matches for this group
            ...matchesForGroup.map((match) => _buildTournamentMatchCard(match)),
            
            const SizedBox(height: AppConstants.spacingM),
          ],
        );
      },
    );
  }

  String _formatMatchDisplayName(dynamic match) {
    final matchName = match['name']?.toString() ?? '';
    final round = match['round']?.toString().toLowerCase() ?? '';
    final instance = match['instance']?.toString() ?? '';
    final matchNum = match['matchnum']?.toString() ?? '';

    String number = matchNum.isNotEmpty ? matchNum : instance;
    if (number.isEmpty) {
      final digitMatch = RegExp(r'\d+').firstMatch(matchName);
      if (digitMatch != null) {
        number = digitMatch.group(0)!;
      }
    }

    String prefix = '';
    final nameLower = matchName.toLowerCase();
    if (round.contains('qualification') || nameLower.contains('qualification') || nameLower.contains('qualifier')) {
      prefix = 'Q';
    } else if (round.contains('semifinal')) {
      prefix = 'SF';
    } else if (round.contains('quarter')) {
      prefix = 'QF';
    } else if (round.contains('final')) {
      prefix = 'F';
    } else if (round.contains('practice') || nameLower.contains('practice')) {
      return number.isNotEmpty ? 'Practice $number' : 'Practice';
    }

    if (prefix.isNotEmpty) {
      return number.isNotEmpty ? '$prefix $number' : prefix;
    }

    if (matchName.isNotEmpty) {
      return matchName;
    }

    return number.isNotEmpty ? 'Match $number' : 'Match';
  }

  Widget _buildTournamentMatchCard(dynamic match) {
    final scheduledTime = match['scheduled']?.toString() ?? '';
    final startedTime = match['started']?.toString() ?? '';
    final finishedTime = match['finished']?.toString() ?? '';
    final field = match['field']?.toString() ?? '';
    final round = match['round']?.toString() ?? '';
    final instance = match['instance']?.toString() ?? '';
    final matchnum = match['matchnum']?.toString() ?? '';
    
    // Parse times following VRC RoboScout pattern: started > scheduled > finished
    DateTime? matchDateTime;
    String timeString = 'No Time';
    bool isUpcoming = false;
    bool isPast = false;
    bool hasScheduledTime = false;
    String timeType = 'unknown';
    
    // Try to get the most relevant time
    String timeToUse = '';
    if (startedTime.isNotEmpty) {
      timeToUse = startedTime;
      timeType = 'started';
    } else if (scheduledTime.isNotEmpty) {
      timeToUse = scheduledTime;
      timeType = 'scheduled';
      hasScheduledTime = true;
    } else if (finishedTime.isNotEmpty) {
      timeToUse = finishedTime;
      timeType = 'finished';
    }
    
    if (timeToUse.isNotEmpty) {
      try {
        // Parse as UTC and convert to local timezone
        final utcDateTime = DateTime.parse(timeToUse);
        matchDateTime = utcDateTime.toLocal();
        timeString = _formatTime(matchDateTime);
        
        final now = DateTime.now();
        final timeUntilMatch = matchDateTime.difference(now);
        
        if (timeUntilMatch.isNegative) {
          isPast = true;
        } else if (timeUntilMatch.inMinutes <= 30) {
          isUpcoming = true;
        }
      } catch (e) {
        print('Error parsing match time: $e');
        timeString = 'Unknown';
      }
    } else {
      // No timing data available - show unknown
      timeString = 'Unknown';
      timeType = 'unknown';
    }

    final displayName = _formatMatchDisplayName(match);

    final defaultCardColor = Theme.of(context).colorScheme.surface;
    final upcomingColor = AppConstants.vexIQGreen.withOpacity(0.08);
    final pastColor = ThemeUtils.getVeryMutedTextColor(context, opacity: 0.05);
    final cardColor = isUpcoming ? upcomingColor : isPast ? pastColor : defaultCardColor;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        side: BorderSide(
          color: ThemeUtils.getSecondaryTextColor(context).withOpacity(isUpcoming ? 0.12 : 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
            // Time indicator
            Container(
              width: 60,
              child: Column(
                children: [
                  Icon(
                    isUpcoming ? Icons.notification_important : 
                    isPast ? Icons.check_circle : Icons.schedule,
                    color: isUpcoming ? AppConstants.vexIQGreen : 
                           isPast ? ThemeUtils.getSecondaryTextColor(context) : AppConstants.vexIQOrange,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeString,
                    style: AppConstants.caption.copyWith(
                      color: isUpcoming ? AppConstants.vexIQGreen : 
                             isPast ? ThemeUtils.getSecondaryTextColor(context) : AppConstants.vexIQOrange,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: AppConstants.spacingM),
            
            // Match info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: AppConstants.bodyText1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (field.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppConstants.vexIQBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Field $field',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingXS),
                  
                  // Match status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isUpcoming
                              ? AppConstants.vexIQGreen.withOpacity(0.08)
                              : isPast
                                  ? ThemeUtils.getVeryMutedTextColor(context, opacity: 0.08)
                                  : AppConstants.vexIQOrange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : isPast ? 'Completed' : 'Scheduled',
                          style: AppConstants.caption.copyWith(
                            color: isUpcoming ? AppConstants.vexIQGreen :
                                   isPast ? ThemeUtils.getSecondaryTextColor(context) :
                                   AppConstants.vexIQOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.spacingS),
                  
                  // Alliances  
                  Column(
                    children: (match['alliances'] as List<dynamic>? ?? [])
                        .map((alliance) => _buildAllianceRow(alliance))
                        .toList(),
                  ),
                ],
              ),
            ),
            
            // Notification button for upcoming matches
            if (isUpcoming && hasScheduledTime)
              IconButton(
                onPressed: () {
                  // Schedule notification for 30 minutes before match
                  if (matchDateTime != null) {
                    final notificationTime = matchDateTime.subtract(const Duration(minutes: 30));
                    if (notificationTime.isAfter(DateTime.now())) {
                      // TODO: Implement notification scheduling
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Notification scheduled for ${_formatTime(notificationTime)}'),
                          backgroundColor: AppConstants.vexIQGreen,
                        ),
                      );
                    }
                  }
                },
                icon: Icon(
                  Icons.notifications_active,
                  color: AppConstants.vexIQGreen,
                  size: 20,
                ),
                tooltip: 'Set 30-minute reminder',
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateInput) {
    DateTime date;
    
    if (dateInput is String) {
      try {
        // Parse as UTC and convert to local timezone
        final utcDate = DateTime.parse(dateInput);
        date = utcDate.toLocal();
      } catch (e) {
        return dateInput.toString();
      }
    } else if (dateInput is DateTime) {
      date = dateInput;
    } else {
      return dateInput.toString();
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDate = DateTime(date.year, date.month, date.day);
    
    if (matchDate == today) {
      return 'Today';
    } else if (matchDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : hour > 12 ? hour - 12 : hour;
    
    // Get timezone offset
    final timeZoneOffset = dateTime.timeZoneOffset;
    final offsetHours = timeZoneOffset.inHours;
    final offsetMinutes = (timeZoneOffset.inMinutes % 60).abs();
    final offsetSign = timeZoneOffset.isNegative ? '-' : '+';
    final timeZoneString = '${offsetSign}${offsetHours.toString().padLeft(2, '0')}:${offsetMinutes.toString().padLeft(2, '0')}';
    
    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period ($timeZoneString)';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _toggleMatchNotification(dynamic match, DateTime? scheduledTime) async {
    if (scheduledTime == null) return;
    
    final matchId = match['id'] as int?;
    final matchName = match['name']?.toString() ?? 'Unknown Match';
    
    if (matchId != null) {
      try {
        // TODO: Implement notification scheduling
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification toggled for $matchName'),
            backgroundColor: AppConstants.vexIQGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTeamNotificationDialog() {
    final userSettings = Provider.of<UserSettings>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Team Notifications'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<UserSettings>(
                builder: (context, settings, child) => SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Get notified before matches'),
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
                    await settings.setNotificationsEnabled(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (userSettings.notificationsEnabled) ...[
                const Divider(),
                Consumer<UserSettings>(
                  builder: (context, settings, child) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications for:',
                        style: AppConstants.bodyText1,
                      ),
                      const SizedBox(height: 8),
                      if (settings.myTeam != null) ...[
                        ListTile(
                          leading: const Icon(Icons.groups, color: AppConstants.vexIQBlue),
                          title: Text('Team ${settings.myTeam}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showTeamSelectorDialog(context, settings);
                            },
                          ),
                        ),
                      ] else ...[
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Add Team'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showTeamSelectorDialog(context, settings);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Consumer<UserSettings>(
                  builder: (context, settings, child) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minutes before match:',
                        style: AppConstants.bodyText1,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [5, 10, 15, 30, 60].map((minutes) {
                          return ChoiceChip(
                            label: Text('${minutes}m'),
                            selected: settings.notificationMinutesBefore == minutes,
                            onSelected: (selected) async {
                              if (selected) {
                                await settings.setNotificationMinutesBefore(minutes);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTeamSelectorDialog(BuildContext context, UserSettings userSettings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Team'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: SimpleTeamSearchWidget(
            useAPI: true, // Use API-based search
            onTeamSelected: (team) {
              userSettings.setMyTeam(team.number);
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _scheduleTeamNotifications(String teamNumber) {
    // TODO: Implement when notifications are re-enabled
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Team notifications coming soon!'),
        backgroundColor: AppConstants.vexIQGreen,
      ),
    );
  }

  void _scheduleSingleTeamNotification({
    required String teamNumber,
    required dynamic match,
    required dynamic division,
    required dynamic alliance,
    required DateTime notificationTime,
    required DateTime matchTime,
  }) {
    // TODO: Implement when notifications are re-enabled
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Team notifications coming soon!'),
        backgroundColor: AppConstants.vexIQGreen,
      ),
    );
  }

  // Rankings tab implementation (like VRC RoboScout)

  Widget _buildRankingsContentOld() {
    if (_rankingsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading Rankings',
              style: AppConstants.headline6,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _rankingsError!,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No divisions available
    if (_divisions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Divisions Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This event does not have division information available',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No division selected
    if (_selectedDivisionId == null) {
      return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
              Icons.format_list_numbered_outlined,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Select a Division',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Choose a division from the dropdown above to view rankings',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

    // Get rankings for selected division
    final selectedRankings = _rankingsByDivision[_selectedDivisionId] ?? [];
    
    if (selectedRankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_list_numbered_outlined,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Rankings Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No rankings available for the selected division',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort rankings by rank (ascending order - 1st place first)
    final sortedRankings = List<dynamic>.from(selectedRankings);
    sortedRankings.sort((a, b) {
      final rankA = a['rank'] ?? a['position'] ?? 999;
      final rankB = b['rank'] ?? b['position'] ?? 999;
      return rankA.compareTo(rankB);
    });

    // Display rankings for selected division
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: sortedRankings.length,
      itemBuilder: (context, index) {
        final ranking = sortedRankings[index];
        final rank = ranking['rank'] ?? ranking['position'] ?? (index + 1);
        return _buildRankingCard(ranking, rank);
      },
    );
  }

  Widget _buildRankingCard(dynamic ranking, int rank) {
    final teamData = ranking['team'];
    final teamNumber = (teamData is Map) 
        ? (teamData['name']?.toString() ?? 'Unknown')
        : 'Unknown';
    final teamName = (teamData is Map) 
        ? (teamData['team_name']?.toString() ?? '')
        : '';
    
    // VEX IQ rankings have different structure than VRC
    
    // Try to get VEX IQ specific fields first, fallback to VRC fields
    final wins = ranking['wins'] ?? ranking['win'] ?? 0;
    final losses = ranking['losses'] ?? ranking['loss'] ?? 0;
    final ties = ranking['ties'] ?? ranking['tie'] ?? 0;
    final totalMatches = ranking['total_matches'] ?? ranking['matches'] ?? (wins + losses + ties);
    
    // VEX IQ might use different scoring system
    final score = ranking['score'] ?? ranking['total_score'] ?? 0;
    final averageScore = ranking['average_score'] ?? ranking['avg_score'] ?? 0.0;
    final highScore = ranking['high_score'] ?? ranking['highest_score'] ?? 0;
    
    // VRC-style fields (might not be present in VEX IQ)
    final wp = ranking['wp'] ?? ranking['win_points'] ?? 0;
    final ap = ranking['ap'] ?? ranking['autonomous_points'] ?? 0;
    final sp = ranking['sp'] ?? ranking['strength_of_schedule'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          children: [
            // Main ranking row
            Row(
              children: [
                // Rank badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getRankColor(rank).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: AppConstants.bodyText1.copyWith(
                        color: _getRankColor(rank),
                fontWeight: FontWeight.bold,
              ),
            ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                
                // Team info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamNumber,
                        style: AppConstants.bodyText1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (teamName.isNotEmpty)
                        Text(
                          teamName,
                          style: AppConstants.bodyText2.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                      Text(
                        'W: $wins L: $losses T: $ties',
                          style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
                    ],
                  ),
                ),
                
                // Stats - Show VEX IQ appropriate stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (score > 0)
                      Text(
                        'Score: $score',
                    style: AppConstants.bodyText1.copyWith(
                      color: AppConstants.vexIQGreen,
                      fontWeight: FontWeight.bold,
                    ),
                      ),
                    if (averageScore > 0)
                      Text(
                        'Avg: ${averageScore.toStringAsFixed(1)}',
                        style: AppConstants.caption.copyWith(
                          color: AppConstants.vexIQBlue,
                        ),
                      ),
                    if (highScore > 0)
                      Text(
                        'High: $highScore',
                        style: AppConstants.caption.copyWith(
                          color: AppConstants.vexIQOrange,
                        ),
                      ),
                    if (totalMatches > 0)
                      Text(
                        'Matches: $totalMatches',
                        style: AppConstants.caption.copyWith(
                          color: ThemeUtils.getSecondaryTextColor(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            
            // Additional stats row with skills and teamwork data
            const SizedBox(height: AppConstants.spacingS),
            _buildTeamAdditionalStats(teamNumber),
              ],
            ),
          ),
    );
  }

  Widget _buildTeamAdditionalStats(String teamNumber) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getTeamAdditionalStats(teamNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 20,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppConstants.vexIQBlue),
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox.shrink();
        }
        
        final stats = snapshot.data!;
        final combinedSkills = stats['combinedSkills'] ?? 0;
        final avgTeamworkPoints = stats['avgTeamworkPoints'] ?? 0.0;
        
        if (combinedSkills == 0 && avgTeamworkPoints == 0.0) {
          return SizedBox.shrink();
        }
        
        return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
        children: [
            if (combinedSkills > 0) ...[
          Row(
                mainAxisSize: MainAxisSize.min,
            children: [
                  Icon(Icons.emoji_events, size: 12, color: AppConstants.vexIQOrange),
                  const SizedBox(width: 4),
                  Flexible(
                child: Text(
                      'Skills: $combinedSkills',
                      style: AppConstants.caption.copyWith(
                        color: AppConstants.vexIQOrange,
                    fontWeight: FontWeight.w600,
                  ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (avgTeamworkPoints > 0) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_work, size: 12, color: AppConstants.vexIQGreen),
                  const SizedBox(width: 4),
                  Flexible(
                  child: Text(
                      'Team: ${avgTeamworkPoints.toStringAsFixed(1)}',
                    style: AppConstants.caption.copyWith(
                        color: AppConstants.vexIQGreen,
                        fontWeight: FontWeight.w600,
                    ),
                      overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
            ],
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getTeamAdditionalStats(String teamNumber) async {
    try {
      // Find team skills data
      num combinedSkills = 0;
      double avgTeamworkPoints = 0.0;
      int teamworkMatches = 0;
      num totalTeamworkPoints = 0;
      
      // Get skills data for this team
      for (final skill in _skills) {
        final skillTeamData = skill['team'];
        final skillTeamNumber = (skillTeamData is Map) 
            ? (skillTeamData['name']?.toString() ?? '').toUpperCase()
            : '';
        
        if (skillTeamNumber == teamNumber.toUpperCase()) {
          final skillType = skill['type']?.toString() ?? '';
          final skillScore = (skill['score'] ?? 0);
          
          if (skillType == 'driver' || skillType == 'programming') {
            combinedSkills += skillScore;
          }
        }
      }
      
      // Get teamwork match data for this team
      for (final division in _divisions) {
        final divisionId = division['id'] as int;
        final matches = _matchesByDivision[divisionId] ?? [];
        
        for (final match in matches) {
          final matchName = match['name']?.toString() ?? '';
          final alliances = match['alliances'] as List<dynamic>? ?? [];
          
          // Check if this is a teamwork match
          if (matchName.toLowerCase().contains('teamwork') || 
              matchName.toLowerCase().contains('team work')) {
            
            for (final alliance in alliances) {
              final teams = alliance['teams'] as List<dynamic>? ?? [];
              
              for (final team in teams) {
                final teamData = team['team'];
                final matchTeamNumber = (teamData is Map) 
                    ? (teamData['name']?.toString() ?? '').toUpperCase()
                    : '';
                
                if (matchTeamNumber == teamNumber.toUpperCase()) {
                  final allianceScore = (alliance['score'] ?? 0);
                  if (allianceScore > 0) {
                    totalTeamworkPoints += allianceScore;
                    teamworkMatches++;
                  }
                  break;
                }
              }
            }
          }
        }
      }
      
      // Calculate average teamwork points
      if (teamworkMatches > 0) {
        avgTeamworkPoints = totalTeamworkPoints / teamworkMatches;
      }
      
      return {
        'combinedSkills': combinedSkills,
        'avgTeamworkPoints': avgTeamworkPoints,
        'teamworkMatches': teamworkMatches,
      };
    } catch (e) {
      print('Error getting team additional stats: $e');
      return {
        'combinedSkills': 0,
        'avgTeamworkPoints': 0.0,
        'teamworkMatches': 0,
      };
    }
  }

  // Results tab implementation (like Elapse app)
  Widget _buildCombinedResultsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
            children: [
          // Sub-tabs for Rankings and Awards (removed Skills to avoid duplication)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              labelColor: AppConstants.vexIQOrange,
              unselectedLabelColor: ThemeUtils.getSecondaryTextColor(context, opacity: 0.6),
              indicatorColor: AppConstants.vexIQOrange,
              tabs: const [
                Tab(text: 'Rankings', icon: Icon(Icons.format_list_numbered)),
                Tab(text: 'Combined', icon: Icon(Icons.merge)),
                Tab(text: 'Skills', icon: Icon(Icons.emoji_events)),
                Tab(text: 'Awards', icon: Icon(Icons.emoji_events)),
              ],
            ),
          ),
          
          // Tab content
              Expanded(
            child: TabBarView(
              children: [
                _buildRankingsView(),
                _buildCombinedRankingsView(),
                _buildSkillsRankingsView(),
                _buildAwardsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRankingsView() {
    // Check for error state
    if (_rankingsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading Rankings',
              style: AppConstants.headline6,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _rankingsError!,
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // No divisions available
    if (_divisions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Divisions Available',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This event may not have divisions yet',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // VEX Via-style division rankings with tabs for each division
    return DefaultTabController(
      length: _divisions.length,
      child: Column(
        children: [
          // Division tabs (like VEX Via)
          Container(
                  decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              isScrollable: true,
              labelColor: AppConstants.vexIQOrange,
              unselectedLabelColor: ThemeUtils.getSecondaryTextColor(context, opacity: 0.6),
              indicatorColor: AppConstants.vexIQOrange,
              onTap: (index) {
                setState(() {
                  _selectedDivisionId = _divisions[index]['id'] as int;
                });
              },
              tabs: _divisions.map<Widget>((division) {
                final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
                final teamCount = _rankingsByDivision[division['id']]?.length ?? 0;
                
                return Tab(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        divisionName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '$teamCount teams',
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                ),
            ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Division rankings content
          Expanded(
            child: TabBarView(
              children: _divisions.map<Widget>((division) {
                final divisionId = division['id'] as int;
                return _buildDivisionRankingsView(divisionId);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionRankingsView(int divisionId) {
    // Get rankings for this specific division
    final selectedRankings = _rankingsByDivision[divisionId] ?? [];
    
    if (selectedRankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_list_numbered_outlined,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Rankings Found',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No rankings available for this division yet',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
  
    // Sort rankings by rank (ascending order - 1st place first)
    final sortedRankings = List<dynamic>.from(selectedRankings);
    sortedRankings.sort((a, b) {
      final rankA = a['rank'] ?? a['position'] ?? 999;
      final rankB = b['rank'] ?? b['position'] ?? 999;
      return rankA.compareTo(rankB);
    });

    return Column(
        children: [
        // Division header with team count and refresh button (like VEX Via)
          Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          color: AppConstants.vexIQOrange.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.groups,
                color: AppConstants.vexIQOrange,
                size: 20,
          ),
          const SizedBox(width: AppConstants.spacingS),
              Text(
                '${sortedRankings.length} Teams',
                style: AppConstants.bodyText1.copyWith(
                  color: AppConstants.vexIQOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _loadEventRankingsForAllDivisions();
                },
                icon: Icon(
                  Icons.refresh,
                  color: AppConstants.vexIQOrange,
                  size: 20,
                ),
                tooltip: 'Refresh Rankings',
              ),
              Text(
                'Division Rankings',
                style: AppConstants.caption.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
        
        
        // Rankings list
          Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            itemCount: sortedRankings.length,
            itemBuilder: (context, index) {
              final ranking = sortedRankings[index];
              final rank = ranking['rank'] ?? ranking['position'] ?? (index + 1);
              return FutureBuilder<Widget>(
                future: _buildDetailedRankingCard(ranking, rank),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!;
                  } else {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Future<Widget> _buildDetailedRankingCard(dynamic ranking, int rank) async {
    final teamData = ranking['team'];
    
    // Debug: Print the actual ranking data structure
    print('🔍 VEX IQ Ranking Data Structure:');
    print('  Keys: ${ranking.keys.toList()}');
    print('  Full ranking: $ranking');
    print('🔍 Team Data: $teamData');
    if (teamData is Map) {
      print('  Team keys: ${teamData.keys.toList()}');
    }
    final teamNumber = (teamData is Map) 
        ? (teamData['name']?.toString() ?? 
           teamData['number']?.toString() ?? 
           'Unknown')
        : 'Unknown';
    
    // Try multiple fields for team name, excluding the number field
    String teamName = (teamData is Map) 
        ? (teamData['teamName']?.toString() ??
           teamData['team_name']?.toString() ?? 
           teamData['robot_name']?.toString() ?? 
           teamData['organization']?.toString() ?? 
           teamData['nickname']?.toString() ?? 
           teamData['display_name']?.toString() ?? 
           '')
        : '';
    
    // If no team name found in API data, try to find it in our cached team database
    if (teamName.isEmpty) {
      teamName = await _getTeamNameFromCache(teamNumber);
      if (teamName.isEmpty) {
        teamName = 'VEX IQ Team';
      }
    }
    
    // Debug: Print all ranking data fields
    print('🔍 Ranking data fields: ${ranking.keys.toList()}');
    print('🔍 Ranking values: $ranking');
    
    // VEX IQ rankings data - use correct field names from API
    final wins = ranking['wins'] ?? 0;
    final losses = ranking['losses'] ?? 0;
    final ties = ranking['ties'] ?? 0;
    final totalScore = ranking['total_points'] ?? 0;
    final averageScore = ranking['average_points'] ?? 0.0;
    final highScore = ranking['high_score'] ?? 0;
    
    // Calculate actual matches played from total points and average
    // VEX IQ uses average scores, not win/loss records
    final calculatedMatches = (averageScore > 0 && totalScore > 0) 
        ? (totalScore / averageScore).round() 
        : 0;
    
    // Use calculated matches if we have scores, otherwise use win/loss (which will be 0 for VEX IQ)
    final totalMatches = calculatedMatches > 0 ? calculatedMatches : (wins + losses + ties);
    
    // Calculate average if we have total and matches but no average
    final calculatedAverage = (totalMatches > 0 && ranking['total'] != null) 
        ? (ranking['total'] / totalMatches).toDouble()
        : averageScore;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: InkWell(
                  onTap: () {
          // Navigate to team details
          _navigateToTeamDetails(teamNumber, teamName);
                  },
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
              children: [
              // Main team info row
              Row(
                children: [
                  // Rank badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getRankColor(rank).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                    child: Text(
                        '$rank',
                        style: AppConstants.bodyText1.copyWith(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  
                  // Team info
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                      teamNumber,
                          style: AppConstants.bodyText1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          teamName.isNotEmpty ? teamName : 'VEX IQ Team',
                          style: AppConstants.bodyText2.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                        Text(
                          '${totalMatches} matches',
                      style: AppConstants.caption.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Favorite star
                  Consumer<UserSettings>(
                    builder: (context, settings, child) {
                      final isFavorite = settings.isFavoriteTeam(teamNumber);
                      return IconButton(
                        onPressed: () {
                          if (isFavorite) {
                            settings.removeFavoriteTeam(teamNumber);
                          } else {
                            settings.addFavoriteTeam(teamNumber);
                          }
                        },
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber : Theme.of(context).iconTheme.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingS),
              
              // Detailed stats row (like RoboScout)
            Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
              decoration: BoxDecoration(
                  color: Colors.grey[50],
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
              ),
                child: Column(
                  children: [
                    // First row: Basic stats
                    Row(
                      children: [
                        // Column 1: Basic stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                          Text(
                            'Avg: ${calculatedAverage.toStringAsFixed(1)}',
                style: AppConstants.caption.copyWith(
                  color: AppConstants.vexIQGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'High: $highScore',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQBlue,
                            ),
                          ),
                          Text(
                            'Matches: $totalMatches',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQOrange,
              ),
            ),
        ],
            ),
          ),
        
                        // Column 2: Match stats
        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                          Text(
                            'Rank: $rank',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                          Text(
                            'Division: ${_getDivisionName(_selectedDivisionId ?? 0)}',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                          Text(
                            'Status: ${totalMatches > 0 ? 'Active' : 'Pending'}',
                            style: AppConstants.caption.copyWith(
                              color: totalMatches > 0 ? AppConstants.vexIQGreen : AppConstants.vexIQOrange,
                            ),
                          ),
                        ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: AppConstants.spacingS),
                    
                    // Second row: Skills and teamwork stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildTeamAdditionalStats(teamNumber),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getDivisionName(int divisionId) {
    final division = _divisions.firstWhere(
      (d) => d['id'] == divisionId,
      orElse: () => {'name': 'Unknown Division'},
    );
    return division['name']?.toString() ?? 'Unknown Division';
  }

  void _shareEvent() {
    // Generate RobotEvents URL using the event's SKU code
    // Format: https://www.robotevents.com/robot-competitions/vex-iq-competition/{SKU}.html#general-info
    final robotEventsUrl = 'https://www.robotevents.com/robot-competitions/vex-iq-competition/${widget.event.sku}.html#general-info';
    
    // Format the start date
    final startDate = widget.event.start != null 
        ? widget.event.start!.toString().split(' ')[0]
        : 'TBD';
    
    // Create share text with event details
    final shareText = 'Check out this VEX IQ event: ${widget.event.name}\n\n'
        '📅 $startDate\n'
        '📍 ${widget.event.location}\n'
        '🔗 $robotEventsUrl\n\n'
        'Shared via StatIQ App';
    
    // Use the native share menu
    Share.share(
      shareText,
      subject: 'VEX IQ Event: ${widget.event.name}',
    );
  }

  Future<String> _getTeamNameFromCache(String teamNumber) async {
    try {
      // Get team by number directly from cache
      final teamData = await TeamSyncService.getTeamByNumber(teamNumber);
      if (teamData != null) {
        final teamName = (teamData['name'] ?? '').toString();
        if (teamName.isNotEmpty) {
          print('✅ Found team name in cache: $teamNumber -> $teamName');
          return teamName;
        }
      }
      print('⚠️ No team name found in cache for $teamNumber');
      } catch (e) {
      print('❌ Error searching cached team database for $teamNumber: $e');
    }
    return '';
  }

  Future<Team?> _getFullTeamDataFromCache(String teamNumber) async {
    try {
      // Search in our cached team database using OptimizedTeamSearch
      final searchResults = OptimizedTeamSearch.search(teamNumber);
      if (searchResults.isNotEmpty) {
        // Find exact match
        for (final teamData in searchResults) {
          final cachedTeamNumber = (teamData['number'] ?? '').toString();
          if (cachedTeamNumber.toLowerCase() == teamNumber.toLowerCase()) {
            print('✅ Found full team data in cache for $teamNumber');
            return Team(
              id: teamData['id'] ?? 0,
              number: teamData['number'] ?? '',
              name: teamData['name'] ?? '',
              robotName: teamData['robotName'] ?? '',
              organization: teamData['organization'] ?? '',
              city: teamData['city'] ?? '',
              region: teamData['region'] ?? '',
              country: teamData['country'] ?? '',
              grade: teamData['grade'] ?? '',
              registered: true,
            );
          }
        }
      }
      print('⚠️ No full team data found in cache for $teamNumber');
      } catch (e) {
      print('❌ Error searching cached team database for $teamNumber: $e');
    }
    return null;
  }

  Future<void> _navigateToTeamDetails(String teamNumber, String teamName) async {
    try {
      // First try to get full team data from cache
      final cachedTeam = await _getFullTeamDataFromCache(teamNumber);
      
      if (cachedTeam != null) {
        // Use cached team data with event context (Bug Patch 3 requirement)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamDetailsScreen(
              team: cachedTeam,
              eventId: widget.event.id, // Pass event ID to filter matches
            ),
          ),
        );
      } else {
        // Fallback: create minimal team object and let TeamDetailsScreen fetch data
        final fallbackTeam = Team(
          id: 0, // Will be fetched by TeamDetailsScreen
          number: teamNumber,
          name: teamName,
          robotName: '',
          organization: '',
          city: '',
          region: '',
          country: '',
          grade: '',
          registered: true,
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamDetailsScreen(
              team: fallbackTeam,
              eventId: widget.event.id, // Pass event ID to filter matches
            ),
          ),
        );
      }
      } catch (e) {
      print('❌ Error navigating to team details: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading team details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCombinedRankingsView() {
    // Combine all rankings from all divisions
    List<dynamic> allRankings = [];
    for (final division in _divisions) {
      final divisionId = division['id'] as int;
      final divisionRankings = _rankingsByDivision[divisionId] ?? [];
      
      // Add division info to each ranking
      for (final ranking in divisionRankings) {
        final rankingWithDivision = Map<String, dynamic>.from(ranking);
        rankingWithDivision['division_name'] = division['name']?.toString() ?? 'Unknown Division';
        rankingWithDivision['division_id'] = divisionId;
        allRankings.add(rankingWithDivision);
      }
    }
    
    if (allRankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.merge,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Combined Rankings',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No rankings available across all divisions',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Sort by rank across all divisions
    allRankings.sort((a, b) {
      final rankA = a['rank'] ?? a['position'] ?? 999;
      final rankB = b['rank'] ?? b['position'] ?? 999;
      return rankA.compareTo(rankB);
    });
    
    return Column(
      children: [
        // Combined rankings header
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          color: AppConstants.vexIQBlue.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.merge,
                color: AppConstants.vexIQBlue,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                '${allRankings.length} Teams (All Divisions)',
                style: AppConstants.bodyText1.copyWith(
                  color: AppConstants.vexIQBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _loadEventRankingsForAllDivisions();
                },
                icon: Icon(
                  Icons.refresh,
                  color: AppConstants.vexIQBlue,
                  size: 20,
                ),
                tooltip: 'Refresh Rankings',
              ),
              Text(
                'Combined Rankings',
                style: AppConstants.caption.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
        
        // Combined rankings list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            itemCount: allRankings.length,
            itemBuilder: (context, index) {
              final ranking = allRankings[index];
              final rank = ranking['rank'] ?? ranking['position'] ?? (index + 1);
              return FutureBuilder<Widget>(
                future: _buildCombinedRankingCard(ranking, rank),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!;
                  } else {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Widget> _buildCombinedRankingCard(dynamic ranking, int rank) async {
    final teamData = ranking['team'];
    final teamNumber = (teamData is Map) 
        ? (teamData['name']?.toString() ?? 
           teamData['number']?.toString() ?? 
           'Unknown')
        : 'Unknown';
    
    // Try multiple fields for team name, excluding the number field
    String teamName = (teamData is Map) 
        ? (teamData['teamName']?.toString() ??
           teamData['team_name']?.toString() ?? 
           teamData['robot_name']?.toString() ?? 
           teamData['organization']?.toString() ?? 
           teamData['nickname']?.toString() ?? 
           teamData['display_name']?.toString() ?? 
           '')
        : '';
    
    // If no team name found in API data, try to find it in our cached team database
    if (teamName.isEmpty) {
      teamName = await _getTeamNameFromCache(teamNumber);
      if (teamName.isEmpty) {
        teamName = 'VEX IQ Team';
      }
    }
    
    // VEX IQ rankings data - use correct field names from API
    final wins = ranking['wins'] ?? 0;
    final losses = ranking['losses'] ?? 0;
    final ties = ranking['ties'] ?? 0;
    final totalScore = ranking['total_points'] ?? 0;
    final averageScore = ranking['average_points'] ?? 0.0;
    final highScore = ranking['high_score'] ?? 0;
    
    // Calculate actual matches played from total points and average
    // VEX IQ uses average scores, not win/loss records
    final calculatedMatches = (averageScore > 0 && totalScore > 0) 
        ? (totalScore / averageScore).round() 
        : 0;
    
    // Use calculated matches if we have scores, otherwise use win/loss (which will be 0 for VEX IQ)
    final totalMatches = calculatedMatches > 0 ? calculatedMatches : (wins + losses + ties);
    
    // Calculate average if we have total and matches but no average
    final calculatedAverage = (totalMatches > 0 && ranking['total'] != null) 
        ? (ranking['total'] / totalMatches).toDouble()
        : averageScore;
    
    final divisionName = ranking['division_name'] ?? 'Unknown Division';
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: InkWell(
        onTap: () {
          // Navigate to team details
          _navigateToTeamDetails(teamNumber, teamName);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
            children: [
              // Main team info row
              Row(
                children: [
                  // Rank badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getRankColor(rank).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: AppConstants.bodyText1.copyWith(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  
                  // Team info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamNumber,
                          style: AppConstants.bodyText1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          teamName.isNotEmpty ? teamName : 'VEX IQ Team',
                          style: AppConstants.bodyText2.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                        Text(
                          '$divisionName • ${totalMatches} matches',
                          style: AppConstants.caption.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Favorite star
                  Consumer<UserSettings>(
                    builder: (context, settings, child) {
                      final isFavorite = settings.isFavoriteTeam(teamNumber);
                      return IconButton(
                        onPressed: () {
                          if (isFavorite) {
                            settings.removeFavoriteTeam(teamNumber);
                          } else {
                            settings.addFavoriteTeam(teamNumber);
                          }
                        },
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber : Theme.of(context).iconTheme.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingS),
              
              // Stats row
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                ),
                child: Row(
                  children: [
                    // Column 1: Basic stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Avg: ${calculatedAverage.toStringAsFixed(1)}',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'High: $highScore',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQBlue,
                            ),
                          ),
                          Text(
                            'Matches: $totalMatches',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Column 2: Division and status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rank: $rank',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                          Text(
                            'Division: $divisionName',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                          Text(
                            'Status: ${totalMatches > 0 ? 'Active' : 'Pending'}',
                            style: AppConstants.caption.copyWith(
                              color: totalMatches > 0 ? AppConstants.vexIQGreen : AppConstants.vexIQOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Column 3: Skills and teamwork
                    Expanded(
                      child: _buildTeamAdditionalStats(teamNumber),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsRankingsView() {
    if (_isLoadingSkills) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_skillsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading Skills',
              style: AppConstants.headline6,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _skillsError!,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_skills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Skills Data',
              style: AppConstants.headline6.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No skills rankings available for this event',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group skills by team and calculate combined scores
    final Map<String, Map<String, dynamic>> teamSkillsMap = {};
    
    for (final skill in _skills) {
      final teamData = skill['team'];
      final teamNumber = (teamData is Map) 
          ? (teamData['name']?.toString() ?? teamData['number']?.toString() ?? '')
          : '';
      
      if (teamNumber.isNotEmpty) {
        if (!teamSkillsMap.containsKey(teamNumber)) {
          teamSkillsMap[teamNumber] = {
            'team': teamData,
            'driver': 0,
            'programming': 0,
            'combined': 0,
          };
        }
        
        final skillType = skill['type']?.toString() ?? '';
        final score = skill['scores']?['score'] ?? skill['score'] ?? 0;
        
        if (skillType == 'driver') {
          teamSkillsMap[teamNumber]!['driver'] = score;
        } else if (skillType == 'programming') {
          teamSkillsMap[teamNumber]!['programming'] = score;
        }
      }
    }
    
    // Calculate combined scores and create sorted list
    final List<Map<String, dynamic>> sortedSkills = [];
    for (final entry in teamSkillsMap.entries) {
      final teamData = entry.value;
      final combined = (teamData['driver'] as int) + (teamData['programming'] as int);
      teamData['combined'] = combined;
      sortedSkills.add(teamData);
    }
    
    // Sort by combined score (highest first)
    sortedSkills.sort((a, b) {
      final scoreA = a['combined'] ?? 0;
      final scoreB = b['combined'] ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return Column(
        children: [
        // Skills header
          Container(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          color: AppConstants.vexIQGreen.withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: AppConstants.vexIQGreen,
                size: 20,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                '${sortedSkills.length} Teams',
                style: AppConstants.bodyText1.copyWith(
                  color: AppConstants.vexIQGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _loadEventSkills();
                },
                icon: Icon(
                  Icons.refresh,
                  color: AppConstants.vexIQGreen,
                  size: 20,
                ),
                tooltip: 'Refresh Skills',
              ),
              Text(
                'Skills Rankings',
                style: AppConstants.caption.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              ),
              ],
            ),
          ),
        
        // Skills rankings list
          Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            itemCount: sortedSkills.length,
            itemBuilder: (context, index) {
              final skill = sortedSkills[index];
              final rank = index + 1;
              return FutureBuilder<Widget>(
                future: _buildSkillsRankingCard(skill, rank),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!;
                  } else {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                },
              );
            },
            ),
          ),
        ],
    );
  }

  Future<Widget> _buildSkillsRankingCard(Map<String, dynamic> teamSkillData, int rank) async {
    final teamData = teamSkillData['team'];
    final teamNumber = (teamData is Map) 
        ? (teamData['name']?.toString() ?? 
           teamData['number']?.toString() ?? 
           'Unknown')
        : 'Unknown';
    
    // Try multiple fields for team name
    String teamName = (teamData is Map) 
        ? (teamData['teamName']?.toString() ??
           teamData['team_name']?.toString() ?? 
           teamData['robot_name']?.toString() ?? 
           teamData['organization']?.toString() ?? 
           teamData['nickname']?.toString() ?? 
           teamData['display_name']?.toString() ?? 
           '')
        : '';
    
    // If no team name found in API data, try to find it in our cached team database
    if (teamName.isEmpty) {
      teamName = await _getTeamNameFromCache(teamNumber);
      if (teamName.isEmpty) {
        teamName = 'VEX IQ Team';
      }
    }
    
    // Get pre-calculated scores
    final combinedScore = teamSkillData['combined'] ?? 0;
    final driverScore = teamSkillData['driver'] ?? 0;
    final programmingScore = teamSkillData['programming'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: InkWell(
        onTap: () {
          // Navigate to team details
          _navigateToTeamDetails(teamNumber, teamName);
        },
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
          children: [
              // Main team info row
              Row(
                children: [
                  // Rank badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                      color: _getRankColor(rank).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                        '$rank',
                  style: AppConstants.bodyText1.copyWith(
                          color: _getRankColor(rank),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingM),
                  
                  // Team info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamNumber,
                    style: AppConstants.bodyText1.copyWith(
                      fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          teamName.isNotEmpty ? teamName : 'VEX IQ Team',
                          style: AppConstants.bodyText2.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                        Text(
                          'Skills Rank #$rank',
                          style: AppConstants.caption.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Favorite star
                  Consumer<UserSettings>(
                    builder: (context, settings, child) {
                      final isFavorite = settings.isFavoriteTeam(teamNumber);
                      return IconButton(
                        onPressed: () {
                          if (isFavorite) {
                            settings.removeFavoriteTeam(teamNumber);
                          } else {
                            settings.addFavoriteTeam(teamNumber);
                          }
                        },
                        icon: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          color: isFavorite ? Colors.amber : Theme.of(context).iconTheme.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.spacingS),
              
              // Skills scores row
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                ),
                child: Row(
                    children: [
                    // Column 1: Combined score
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Combined: $combinedScore',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Driver: $driverScore',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQBlue,
                            ),
                          ),
                          Text(
                            'Programming: $programmingScore',
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.vexIQOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Column 2: Skills breakdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skills Rank: $rank',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                          Text(
                            'Total Teams: ${_skills.length}',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                          Text(
                            'Percentile: ${((_skills.length - rank + 1) / _skills.length * 100).toStringAsFixed(1)}%',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                  ),
                ],
              ),
            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAwardsView() {
    if (_isLoadingAwards) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_awardsError != null) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
              Icon(
              Icons.error_outline,
              size: 64,
                color: ThemeUtils.getSecondaryTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Error Loading Awards',
              style: AppConstants.headline6,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              _awardsError!,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          ),
      );
    }

    if (_awards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
            size: 64,
            color: ThemeUtils.getVeryMutedTextColor(context),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
              'No Awards Available',
            style: AppConstants.headline6.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
              'Awards will appear here once available',
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _awards.length,
      itemBuilder: (context, index) {
        final award = _awards[index];
        
        // Safe type conversion for award data
        final awardName = award['title']?.toString() ?? 
                         award['name']?.toString() ?? 
                         award['award']?.toString() ?? 
                         'Unknown Award';
        final awardOrder = award['order']?.toString() ?? '';
        // Awards have team data in teamWinners array
        final teamWinners = award['teamWinners'] as List<dynamic>? ?? [];
        final winnerLabels = <String>[];
        for (final winner in teamWinners) {
          final winnerMap = winner is Map<String, dynamic> ? winner : null;
          final teamData = winnerMap?['team'] ?? winnerMap;
          if (teamData is Map<String, dynamic>) {
            final number = teamData['number']?.toString() ??
                teamData['name']?.toString() ??
                teamData['team_number']?.toString();
            if (number != null && number.isNotEmpty) {
              winnerLabels.add(number.toUpperCase());
            }
          }
        }
        
        // Debug: Print award data structure
        print('🔍 Award data: $award');
        print('🔍 Team winners: $teamWinners');
        print('🔍 Winner labels: $winnerLabels');
        
        final teamNumber = winnerLabels.isNotEmpty
            ? winnerLabels.join(' & ')
            : 'Unknown Team';

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
              children: [
                // Award icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQOrange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: AppConstants.vexIQOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                
                // Award info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        awardName,
                        style: AppConstants.bodyText1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        teamNumber,
                        style: AppConstants.bodyText2.copyWith(
                          color: AppConstants.vexIQBlue,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildSkillsListView(List<dynamic> skills, String skillType) {
    if (skills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No $skillType Records',
              style: AppConstants.bodyText1.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
              children: [
        // Header row (RoboScout style)
                Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
                  decoration: BoxDecoration(
            color: AppConstants.vexIQBlue.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: AppConstants.vexIQBlue.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
        child: Row(
          children: [
              SizedBox(
                width: 50,
                    child: Text(
                  'Rank',
                  style: AppConstants.caption.copyWith(
                fontWeight: FontWeight.bold,
                    color: AppConstants.vexIQBlue,
              ),
            ),
                  ),
                Expanded(
                flex: 2,
                child: Text(
                  'Team',
                  style: AppConstants.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.vexIQBlue,
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Score',
                          style: AppConstants.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.vexIQBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Attempts',
                  style: AppConstants.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.vexIQBlue,
                  ),
                  textAlign: TextAlign.center,
              ),
            ),
                    ],
                  ),
                ),
        // Skills list
        Expanded(
          child: ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];
              final rank = index + 1;
              
              // Safe type conversion for team name
              final teamData = skill['team'];
              final teamNumber = (teamData is Map) 
                  ? (teamData['name']?.toString() ?? 'Unknown Team')
                  : 'Unknown Team';
              
              // Safe type conversion for score
              final scoreData = skill['score'];
              final score = (scoreData is int) 
                  ? scoreData 
                  : (scoreData is String) 
                      ? int.tryParse(scoreData) ?? 0 
                      : 0;
              
              // Safe type conversion for attempts
              final attemptsData = skill['attempts'];
              final attempts = (attemptsData is int) 
                  ? attemptsData 
                  : (attemptsData is String) 
                      ? int.tryParse(attemptsData) ?? 0 
                      : 0;

    return Container(
      padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppConstants.borderColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Rank
                    SizedBox(
                      width: 50,
                      child: Row(
                        children: [
                          if (rank <= 3) ...[
                            Icon(
                              rank == 1 ? Icons.emoji_events : 
                              rank == 2 ? Icons.emoji_events : 
                              Icons.emoji_events,
                              size: 16,
                color: _getRankColor(rank),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            '$rank',
                            style: AppConstants.bodyText2.copyWith(
                    fontWeight: FontWeight.bold,
                              color: _getRankColor(rank),
                  ),
                ),
                        ],
              ),
            ),
                    // Team number
            Expanded(
                      flex: 2,
                  child: Text(
                        teamNumber,
                        style: AppConstants.bodyText2.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Score
                    SizedBox(
                      width: 80,
                      child: Text(
                        '$score',
                        style: AppConstants.bodyText2.copyWith(
                      fontWeight: FontWeight.bold,
                          color: AppConstants.vexIQGreen,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Attempts
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$attempts',
                        style: AppConstants.bodyText2.copyWith(
                          color: ThemeUtils.getSecondaryTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
          ),
        );
      },
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber[700]!; // Gold
    if (rank == 2) return Colors.grey[600]!;   // Silver
    if (rank == 3) return Colors.brown[600]!;  // Bronze
    return AppConstants.vexIQBlue;             // Regular
  }

  Color? _getTeamAllianceColor(String teamNumber) {
    // Check all divisions for this team's alliance color
    for (final division in _divisions) {
      final divisionId = division['id'] as int;
      final matches = _matchesByDivision[divisionId] ?? [];
      
      for (final match in matches) {
        final alliances = match['alliances'] as List<dynamic>? ?? [];
        
        for (final alliance in alliances) {
          final teams = alliance['teams'] as List<dynamic>? ?? [];
          final allianceColor = alliance['color']?.toString() ?? '';
          
          for (final team in teams) {
            final teamData = team['team'];
            final matchTeamNumber = (teamData is Map) 
                ? (teamData['name']?.toString() ?? '').toUpperCase()
                : '';
            
            if (matchTeamNumber == teamNumber.toUpperCase()) {
              if (allianceColor.toLowerCase() == 'red') {
                return Colors.red;
              } else if (allianceColor.toLowerCase() == 'blue') {
                return Colors.blue;
              }
            }
          }
        }
      }
    }
    return null; // No alliance found
  }

  int _getTotalMatchesCount() {
    int total = 0;
    for (final matches in _matchesByDivision.values) {
      total += matches.length;
    }
    return total;
  }
  
  int _getWorldSkillRank() {
    if (_skills.isEmpty) return 0;
    
    // Find the best combined skills score
    int bestScore = 0;
    for (final skill in _skills) {
      final score = (skill['score'] is int) ? skill['score'] as int : int.tryParse(skill['score']?.toString() ?? '0') ?? 0;
      if (score > bestScore) {
        bestScore = score;
      }
    }
    
    // Estimate world rank based on score (this is a simplified calculation)
    // In a real implementation, this would query the global skills database
    if (bestScore >= 200) return 1;
    if (bestScore >= 180) return 5;
    if (bestScore >= 160) return 15;
    if (bestScore >= 140) return 50;
    if (bestScore >= 120) return 100;
    if (bestScore >= 100) return 250;
    if (bestScore >= 80) return 500;
    if (bestScore >= 60) return 1000;
    return 2000;
  }
  
  int _getRegionSkillRank() {
    if (_skills.isEmpty) return 0;
    
    // Find the best combined skills score
    int bestScore = 0;
    for (final skill in _skills) {
      final score = (skill['score'] is int) ? skill['score'] as int : int.tryParse(skill['score']?.toString() ?? '0') ?? 0;
      if (score > bestScore) {
        bestScore = score;
      }
    }
    
    // Estimate region rank based on score (this is a simplified calculation)
    // In a real implementation, this would query the regional skills database
    if (bestScore >= 200) return 1;
    if (bestScore >= 180) return 3;
    if (bestScore >= 160) return 8;
    if (bestScore >= 140) return 20;
    if (bestScore >= 120) return 50;
    if (bestScore >= 100) return 100;
    if (bestScore >= 80) return 200;
    if (bestScore >= 60) return 400;
    return 800;
  }

  int _getWorldSkillsCombinedPts() {
    if (_skills.isEmpty) return 0;
    
    // Find the best combined skills score
    int bestScore = 0;
    for (final skill in _skills) {
      final score = (skill['score'] is int) ? skill['score'] as int : int.tryParse(skill['score']?.toString() ?? '0') ?? 0;
      if (score > bestScore) {
        bestScore = score;
      }
    }
    
    return bestScore;
  }

  Widget _buildMatchCard(BuildContext context, dynamic match) {
    final matchName = match['name']?.toString() ?? 'Unknown Match';
    final round = match['round']?.toString() ?? 'Unknown Round';
    final field = match['field']?.toString() ?? '';
    final scheduledTime = match['scheduled']?.toString();
    final startedTime = match['started']?.toString();
    final finishedTime = match['finished']?.toString();
    
    // Get match alliances/teams
    final alliances = match['alliances'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingXS,
      ),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[800]!.withOpacity(0.3)  // Light grey in dark mode
            : AppConstants.vexIQBlue.withOpacity(0.05),  // Light blue in light mode
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
        border: Border.all(
          color: AppConstants.vexIQBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match header with name and field
          Row(
            children: [
              Expanded(
                child: Text(
                  matchName,
                    style: AppConstants.bodyText1.copyWith(
                      fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (field.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Text(
                    'Field $field',
            style: AppConstants.caption.copyWith(
                      color: AppConstants.vexIQOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          
          // Round and time information
                  Row(
                    children: [
              Expanded(
                child: Text(
            round,
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
              ),
              if (scheduledTime != null || startedTime != null || finishedTime != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getMatchStatusColor(startedTime, finishedTime).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Text(
                    _getMatchTimeDisplay(scheduledTime, startedTime, finishedTime),
            style: AppConstants.caption.copyWith(
                      color: _getMatchStatusColor(startedTime, finishedTime),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          // Teams in alliances (if available)
          if (alliances.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingS),
            ...alliances.map((alliance) => _buildAllianceRow(alliance)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildAllianceRow(dynamic alliance) {
    final color = alliance['color']?.toString() ?? '';
    final teams = alliance['teams'] as List<dynamic>? ?? [];
    final scoreData = alliance['score'];
    final score = (scoreData is int) ? scoreData : null;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
      child: Row(
        children: [
          // Alliance color indicator
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color.toLowerCase() == 'red' ? Colors.red : 
                     color.toLowerCase() == 'blue' ? Colors.blue : 
                     ThemeUtils.getSecondaryTextColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          
          // Team numbers (display only)
          Expanded(
            child: Wrap(
              spacing: AppConstants.spacingS,
              children: teams.map((teamData) {
                final teamDataMap = teamData['team'];
                final teamNumber = (teamDataMap is Map) 
                    ? (teamDataMap['name']?.toString() ?? 'Unknown')
                    : 'Unknown';
    return Container(
      padding: const EdgeInsets.symmetric(
                      horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
                    color: AppConstants.vexIQBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                    ),
                    child: Text(
                      teamNumber,
            style: AppConstants.caption.copyWith(
                      color: AppConstants.vexIQBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Score (if available)
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppConstants.vexIQGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
              ),
              child: Text(
                score.toString(),
            style: AppConstants.caption.copyWith(
                  color: AppConstants.vexIQGreen,
                  fontWeight: FontWeight.bold,
            ),
              ),
          ),
        ],
      ),
    );
  }

  Color _getMatchStatusColor(String? startedTime, String? finishedTime) {
    if (finishedTime != null) return AppConstants.vexIQGreen; // Completed
    if (startedTime != null) return AppConstants.vexIQOrange; // In Progress
    return AppConstants.vexIQBlue; // Scheduled
  }
  
  String _getMatchTimeDisplay(String? scheduledTime, String? startedTime, String? finishedTime) {
    if (finishedTime != null) {
      try {
        final time = DateTime.parse(finishedTime);
        return 'Finished ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Finished';
      }
    }
    
    if (startedTime != null) {
      try {
        final time = DateTime.parse(startedTime);
        return 'Started ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'In Progress';
      }
    }
    
    if (scheduledTime != null) {
      try {
        final time = DateTime.parse(scheduledTime);
        return 'Scheduled ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Scheduled';
      }
    }
    
    return 'Not Scheduled';
  }

  Future<void> _scheduleEventNotifications(Map<int, List<dynamic>> matchesByDivision) async {
    if (!mounted) return;
    final userSettings = Provider.of<UserSettings>(context, listen: false);
    if (!userSettings.notificationsEnabled || userSettings.myTeam == null) return;
    final userTeamNumber = userSettings.myTeam!;
    final now = DateTime.now();
    final allMatches = <dynamic>[];
    for (final matches in matchesByDivision.values) {
      allMatches.addAll(matches);
    }
    final futureMatchesWithUserTeam = <dynamic>[];
    for (final match in allMatches) {
      final scheduledTime = match['scheduled']?.toString() ?? '';
      if (scheduledTime.isEmpty) continue;
      DateTime? matchDateTime;
      try {
        final utcDateTime = DateTime.parse(scheduledTime);
        matchDateTime = utcDateTime.toLocal();
        if (!matchDateTime.isAfter(now)) continue;
      } catch (e) {
        continue;
      }
      final alliances = match['alliances'] as List<dynamic>? ?? [];
      bool userTeamInMatch = false;
      for (final alliance in alliances) {
        final teams = alliance['teams'] as List<dynamic>? ?? [];
        for (final teamData in teams) {
          final teamInfo = teamData['team'] as Map<String, dynamic>? ?? teamData as Map<String, dynamic>?;
          if (teamInfo != null) {
            final teamNumber = teamInfo['number'] as String? ?? teamInfo['name'] as String? ?? '';
            if (teamNumber.toLowerCase() == userTeamNumber.toLowerCase()) {
              userTeamInMatch = true;
              break;
            }
          }
        }
        if (userTeamInMatch) break;
      }
      if (userTeamInMatch) {
        futureMatchesWithUserTeam.add({'match': match, 'scheduledTime': matchDateTime});
      }
    }
    print('📱 Found ${futureMatchesWithUserTeam.length} future matches with team $userTeamNumber in event ${widget.event.id}');
    await NotificationService().cancelAllMatchNotifications();
    for (final matchInfo in futureMatchesWithUserTeam) {
      final match = matchInfo['match'] as Map<String, dynamic>;
      final scheduledTime = matchInfo['scheduledTime'] as DateTime;
      try {
        final matchName = match['name']?.toString() ?? 'Match';
        final field = match['field']?.toString() ?? 'Field';
        final matchId = match['id'] as int? ?? 0;
        String divisionName = widget.event.name;
        if (_selectedDivisionId != null) {
          final division = _divisions.firstWhere((d) => d['id'] == _selectedDivisionId, orElse: () => {});
          divisionName = division['name']?.toString() ?? widget.event.name;
        }
        await NotificationService().scheduleMatchNotification(
          matchName: matchName,
          divisionName: divisionName,
          field: field,
          scheduledTime: scheduledTime,
          matchId: matchId,
          minutesBefore: userSettings.notificationMinutesBefore,
          teamNumber: userTeamNumber,
        );
      } catch (e) {
        print('❌ Error scheduling notification for match: $e');
      }
    }
    print('✅ Scheduled ${futureMatchesWithUserTeam.length} notifications for event');
  }

  List<Map<String, dynamic>> _getNext5MatchesForTeam(String teamNumber) {
    final allMatches = <Map<String, dynamic>>[];
    
    // Collect all matches from all divisions
    for (final matches in _matchesByDivision.values) {
      allMatches.addAll(matches.cast<Map<String, dynamic>>());
    }
    
    final now = DateTime.now();
    final teamMatches = <Map<String, dynamic>>[];
    
    for (final match in allMatches) {
      // Check if match has scheduled time
      final scheduledTime = match['scheduled']?.toString() ?? '';
      if (scheduledTime.isEmpty) continue;
      
      // Parse and check if in future
      DateTime? matchDateTime;
      try {
        final utcDateTime = DateTime.parse(scheduledTime);
        matchDateTime = utcDateTime.toLocal();
        if (!matchDateTime.isAfter(now)) continue;
      } catch (e) {
        continue;
      }
      
      // Check if team is in this match
      final alliances = match['alliances'] as List<dynamic>? ?? [];
      bool teamInMatch = false;
      
      for (final alliance in alliances) {
        final teams = alliance['teams'] as List<dynamic>? ?? [];
        for (final teamData in teams) {
          final teamInfo = teamData['team'] as Map<String, dynamic>? ?? teamData as Map<String, dynamic>?;
          if (teamInfo != null) {
            final matchTeamNumber = teamInfo['number'] as String? ?? 
                                   teamInfo['name'] as String? ?? '';
            if (matchTeamNumber.toLowerCase() == teamNumber.toLowerCase()) {
              teamInMatch = true;
              break;
            }
          }
        }
        if (teamInMatch) break;
      }
      
      if (teamInMatch) {
        teamMatches.add({
          'match': match,
          'scheduledTime': matchDateTime!,
        });
      }
    }
    
    // Sort by scheduled time and return top 5
    teamMatches.sort((a, b) => a['scheduledTime'].compareTo(b['scheduledTime']));
    return teamMatches.take(5).toList();
  }

  Widget _buildNextMatchChip(Map<String, dynamic> matchInfo) {
    final match = matchInfo['match'] as Map<String, dynamic>;
    final scheduledTime = matchInfo['scheduledTime'] as DateTime;
    final matchName = match['name']?.toString() ?? 'Match';
    final field = match['field']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppConstants.vexIQGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppConstants.vexIQGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            matchName,
            style: AppConstants.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: AppConstants.vexIQGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')} ${scheduledTime.hour >= 12 ? 'PM' : 'AM'}',
            style: AppConstants.caption.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
          if (field.isNotEmpty)
            Text(
              'Field $field',
              style: AppConstants.caption.copyWith(
                color: AppConstants.vexIQGreen,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }






}

// Division matches screen to show matches for a specific division
class DivisionMatchesScreen extends StatelessWidget {
  final String divisionName;
  final List<dynamic> matches;

  const DivisionMatchesScreen({
    Key? key,
    required this.divisionName,
    required this.matches,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(divisionName),
        backgroundColor: AppConstants.vexIQBlue,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: matches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_esports_outlined,
                    size: 64,
                    color: ThemeUtils.getVeryMutedTextColor(context),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'No Matches Found',
                    style: AppConstants.headline6.copyWith(
                      color: ThemeUtils.getSecondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Matches will appear here once they are scheduled',
                    style: AppConstants.bodyText2.copyWith(
                      color: ThemeUtils.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                return _buildMatchCard(context, matches[index]);
              },
            ),
    );
  }

  Widget _buildMatchCard(BuildContext context, dynamic match) {
    final matchName = match['name']?.toString() ?? 'Unknown Match';
    final round = match['round']?.toString() ?? 'Unknown Round';
    final field = match['field']?.toString() ?? '';
    final scheduledTime = match['scheduled']?.toString();
    final startedTime = match['started']?.toString();
    final finishedTime = match['finished']?.toString();
    
    // Get match alliances/teams
    final alliances = match['alliances'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingXS,
      ),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[800]!.withOpacity(0.3)  // Light grey in dark mode
            : AppConstants.vexIQBlue.withOpacity(0.05),  // Light blue in light mode
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
        border: Border.all(
          color: AppConstants.vexIQBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match header with name and field
          Row(
            children: [
              Expanded(
                child: Text(
                  matchName,
                  style: AppConstants.bodyText1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (field.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Text(
                    'Field $field',
                    style: AppConstants.caption.copyWith(
                      color: AppConstants.vexIQOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          
          // Round and time information
          Row(
            children: [
              Expanded(
                child: Text(
                  round,
                  style: AppConstants.bodyText2.copyWith(
                    color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                ),
              ),
              if (scheduledTime != null || startedTime != null || finishedTime != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getMatchStatusColor(startedTime, finishedTime).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Text(
                    _getMatchTimeDisplay(scheduledTime, startedTime, finishedTime),
                    style: AppConstants.caption.copyWith(
                      color: _getMatchStatusColor(startedTime, finishedTime),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          // Teams in alliances (if available)
          if (alliances.isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingS),
            ...alliances.map((alliance) => _buildAllianceRow(context, alliance)).toList(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildAllianceRow(BuildContext context, dynamic alliance) {
    final color = alliance['color']?.toString() ?? '';
    final teams = alliance['teams'] as List<dynamic>? ?? [];
    final scoreData = alliance['score'];
    final score = (scoreData is int) ? scoreData : null;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
      child: Row(
        children: [
          // Alliance color indicator
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color.toLowerCase() == 'red' ? Colors.red : 
                     color.toLowerCase() == 'blue' ? Colors.blue : 
                     ThemeUtils.getSecondaryTextColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          
          // Team numbers (display only)
          Expanded(
            child: Wrap(
              spacing: AppConstants.spacingS,
              children: teams.map((teamData) {
                final teamDataMap = teamData['team'];
                final teamNumber = (teamDataMap is Map) 
                    ? (teamDataMap['number']?.toString() ?? 
                       teamDataMap['team_number']?.toString() ?? 
                       'Unknown')
                    : 'Unknown';
                final teamName = (teamDataMap is Map) 
                    ? (teamDataMap['name']?.toString() ?? 
                       teamDataMap['team_name']?.toString() ?? 
                       teamDataMap['robot_name']?.toString() ?? 
                       '')
                    : '';
                
                // Determine alliance color
                Color allianceColor = ThemeUtils.getSecondaryTextColor(context);
                if (color.toLowerCase().contains('red')) {
                  allianceColor = Colors.red;
                } else if (color.toLowerCase().contains('blue')) {
                  allianceColor = Colors.blue;
                } else {
                  allianceColor = AppConstants.vexIQBlue;
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: allianceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Text(
                    teamName.isNotEmpty ? '$teamNumber ($teamName)' : teamNumber,
                    style: AppConstants.caption.copyWith(
                      color: allianceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Score (if available)
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppConstants.vexIQGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
              ),
              child: Text(
                score.toString(),
                style: AppConstants.caption.copyWith(
                  color: AppConstants.vexIQGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Color _getMatchStatusColor(String? startedTime, String? finishedTime) {
    if (finishedTime != null) return AppConstants.vexIQGreen; // Completed
    if (startedTime != null) return AppConstants.vexIQOrange; // In Progress
    return AppConstants.vexIQBlue; // Scheduled
  }
  
  String _getMatchTimeDisplay(String? scheduledTime, String? startedTime, String? finishedTime) {
    if (finishedTime != null) {
      try {
        final time = DateTime.parse(finishedTime);
        return 'Finished ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Finished';
      }
    }
    
    if (startedTime != null) {
      try {
        final time = DateTime.parse(startedTime);
        return 'Started ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'In Progress';
      }
    }
    
    if (scheduledTime != null) {
      try {
        final time = DateTime.parse(scheduledTime);
        return 'Scheduled ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return 'Scheduled';
      }
    }
    
    return 'Not Scheduled';
  }

}
