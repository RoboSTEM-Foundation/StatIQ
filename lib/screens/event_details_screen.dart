import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../models/team.dart';
import '../services/robotevents_api.dart';
import '../services/user_settings.dart';
// import '../services/notification_service.dart';
import '../constants/app_constants.dart';
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
    _tabController = TabController(length: 5, vsync: this); // Combined tournament/matches, added awards
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

      // Load matches for each division (like Elapse app pattern)
      Map<int, List<dynamic>> matchesByDivision = {};
      for (final division in _divisions) {
        try {
          final divisionId = division['id'] as int;
          final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
          
          final divisionMatches = await RobotEventsAPI.getEventMatches(
            eventId: widget.event.id,
            divisionId: divisionId,
          );
          
          // Store matches by division ID for easy access
          matchesByDivision[divisionId] = divisionMatches;
          print('Loaded ${divisionMatches.length} matches for division: $divisionName');
          
        } catch (e) {
          print('Error loading matches for division ${division['id']}: $e');
          matchesByDivision[division['id'] as int] = [];
        }
      }
      
      if (mounted) {
        setState(() {
          _matchesByDivision = matchesByDivision;
          _isLoadingMatches = false;
          
          // Set default division if we have divisions
          if (_divisions.isNotEmpty && _selectedDivisionId == null) {
            _selectedDivisionId = _divisions.first['id'] as int;
          }
        });
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

      // Load rankings for each division (like VRC RoboScout)
      Map<int, List<dynamic>> rankingsByDivision = {};
      for (final division in _divisions) {
        try {
          final divisionId = division['id'] as int;
          final divisionName = division['name']?.toString() ?? 'Division ${division['order']?.toString() ?? ''}';
          
          final divisionRankings = await RobotEventsAPI.getEventDivisionRankings(
            eventId: widget.event.id,
            divisionId: divisionId,
          );
          
          // Store rankings by division ID for easy access
          rankingsByDivision[divisionId] = divisionRankings;
          print('Loaded ${divisionRankings.length} rankings for division: $divisionName');
          
        } catch (e) {
          print('Error loading rankings for division ${division['id']}: $e');
          rankingsByDivision[division['id'] as int] = [];
        }
      }
      
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
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<UserSettings>(
            builder: (context, settings, child) {
              final isFavorite = settings.isFavoriteEvent(widget.event.sku);
              return IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : AppConstants.textSecondary,
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
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.vexIQOrange,
          unselectedLabelColor: AppConstants.textSecondary,
          indicatorColor: AppConstants.vexIQOrange,
          tabs: const [
            Tab(text: 'Info', icon: Icon(Icons.info_outline)),
            Tab(text: 'Teams', icon: Icon(Icons.people)),
            Tab(text: 'Tournament', icon: Icon(Icons.schedule)),
            Tab(text: 'Rankings', icon: Icon(Icons.format_list_numbered)),
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
          _buildRankingsTab(),
          _buildResultsTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventInfoCard(),
          const SizedBox(height: AppConstants.spacingM),
          _buildLocationCard(),
          const SizedBox(height: AppConstants.spacingM),
          _buildDivisionsCard(),
          const SizedBox(height: AppConstants.spacingM),
          _buildQuickStatsCard(),
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
                  color: AppConstants.textSecondary,
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
                    'Teams',
                    _isLoadingTeams ? '...' : _teams.length.toString(),
                    Icons.people,
                    AppConstants.vexIQBlue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Matches',
                    _isLoadingMatches ? '...' : _getTotalMatchesCount().toString(),
                    Icons.sports_esports,
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
                    'Skills',
                    _isLoadingSkills ? '...' : _skills.length.toString(),
                    Icons.emoji_events,
                    AppConstants.vexIQOrange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Divisions',
                    _isLoadingDivisions ? '...' : _divisions.length.toString(),
                    Icons.group_work,
                    AppConstants.vexIQRed,
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
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary,
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
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Teams Found',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This event has no registered teams yet',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
        final allianceColor = _getTeamAllianceColor(team.number);
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConstants.vexIQOrange,
              child: Text(
                team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
                style: AppConstants.bodyText2.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(team.number)),
                if (allianceColor != null)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: allianceColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (team.name.isNotEmpty) Text(team.name),
                if (team.organization.isNotEmpty) 
                  Text(
                    team.organization,
                    style: AppConstants.caption,
                  ),
                if (allianceColor != null)
                  Text(
                    'Alliance: ${allianceColor == Colors.red ? 'Red' : 'Blue'}',
                    style: AppConstants.caption.copyWith(
                      color: allianceColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            trailing: Consumer<UserSettings>(
              builder: (context, settings, child) {
                final isFavorite = settings.isFavoriteTeam(team.number);
                return IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : AppConstants.textSecondary,
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
              // Navigate to team details
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
              color: AppConstants.textSecondary,
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
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Divisions Found',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'This event does not have division information available',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Select a Division',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Choose a division from the dropdown above to view matches',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Matches Found',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No matches available for the selected division',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
        return _buildMatchCard(selectedMatches[index]);
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
          child: Row(
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
                      'Get notified 1 hour before your team\'s matches',
                      style: AppConstants.caption.copyWith(
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showTeamNotificationDialog(),
                icon: Icon(Icons.add, size: 16),
                label: Text('Add Team'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.vexIQGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingM,
                    vertical: AppConstants.spacingS,
                  ),
                ),
              ),
            ],
          ),
        ),
        
                // Division selector header
        if (_divisions.isNotEmpty) 
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Select a Division',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Choose a division to view match schedules',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Matches Found',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No matches available for the selected division',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
                    ? AppConstants.vexIQGreen.withOpacity(0.1)
                    : groupName.contains('Past')
                        ? AppConstants.vexIQOrange.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                            : Colors.grey,
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
                                : Colors.grey,
                      ),
                    ),
                  ),
                  Text(
                    '${matchesForGroup.length} matches',
                    style: AppConstants.caption.copyWith(
                      color: AppConstants.textSecondary,
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

  Widget _buildTournamentMatchCard(dynamic match) {
    final matchName = match['name']?.toString() ?? 'Unknown Match';
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

    // Format match name with readable terms
    String displayName = matchName;
    if (displayName.contains('Qualifier')) {
      final matchNumber = matchnum.isNotEmpty ? matchnum : instance.isNotEmpty ? instance : '';
      displayName = 'Qualifier $matchNumber';
    } else if (displayName.contains('Practice')) {
      final matchNumber = matchnum.isNotEmpty ? matchnum : instance.isNotEmpty ? instance : '';
      displayName = 'Practice $matchNumber';
    } else if (displayName.contains('Final')) {
      final matchNumber = matchnum.isNotEmpty ? matchnum : instance.isNotEmpty ? instance : '';
      displayName = 'Final $matchNumber';
    } else {
      // Use instance and matchnum for other match types
      if (instance.isNotEmpty && matchnum.isNotEmpty) {
        displayName = 'Match $instance-$matchnum';
      } else if (instance.isNotEmpty) {
        displayName = 'Match $instance';
      } else if (matchnum.isNotEmpty) {
        displayName = 'Match $matchnum';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      color: isUpcoming ? AppConstants.vexIQGreen.withOpacity(0.1) : 
             isPast ? AppConstants.textSecondary.withOpacity(0.1) : Colors.white,
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
                           isPast ? AppConstants.textSecondary : AppConstants.vexIQOrange,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeString,
                    style: AppConstants.caption.copyWith(
                      color: isUpcoming ? AppConstants.vexIQGreen : 
                             isPast ? AppConstants.textSecondary : AppConstants.vexIQOrange,
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
                          color: isUpcoming ? AppConstants.vexIQGreen.withOpacity(0.1) :
                                 isPast ? AppConstants.textSecondary.withOpacity(0.1) :
                                 AppConstants.vexIQOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : isPast ? 'Completed' : 'Scheduled',
                          style: AppConstants.caption.copyWith(
                            color: isUpcoming ? AppConstants.vexIQGreen :
                                   isPast ? AppConstants.textSecondary :
                                   AppConstants.vexIQOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppConstants.spacingS),
                  
                  // Alliances
                  _buildAllianceRow(match),
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
    // TODO: Implement when notifications are re-enabled
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Team notifications coming soon!'),
        backgroundColor: AppConstants.vexIQGreen,
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
  Widget _buildRankingsTab() {
    return Column(
      children: [
        // Division selector header
        if (_divisions.isNotEmpty) 
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered, color: AppConstants.vexIQOrange),
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
                      final rankingCount = _rankingsByDivision[divisionId]?.length ?? 0;
                      
                      return DropdownMenuItem<int>(
                        value: divisionId,
                        child: Text('$divisionName ($rankingCount teams)'),
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
        
        // Rankings content
        Expanded(
          child: _buildRankingsContent(),
        ),
      ],
    );
  }

  Widget _buildRankingsContent() {
    if (_rankingsError != null) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              Icons.error_outline,
              size: 64,
              color: AppConstants.textSecondary,
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
                color: AppConstants.textSecondary,
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
            color: AppConstants.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
              'No Divisions Found',
            style: AppConstants.headline6.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
              'This event does not have division information available',
            style: AppConstants.bodyText2.copyWith(
              color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'Select a Division',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Choose a division from the dropdown above to view rankings',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Rankings Found',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'No rankings available for the selected division',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Display rankings for selected division
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: selectedRankings.length,
      itemBuilder: (context, index) {
        return _buildRankingCard(selectedRankings[index], index + 1);
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
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      Text(
                        'W: $wins L: $losses T: $ties',
                        style: AppConstants.caption.copyWith(
                          color: AppConstants.textSecondary,
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
                          color: AppConstants.textSecondary,
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
        
        return Container(
          padding: const EdgeInsets.all(AppConstants.spacingS),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
          ),
          child: Row(
            children: [
              if (combinedSkills > 0) ...[
                Icon(Icons.emoji_events, size: 16, color: AppConstants.vexIQOrange),
                const SizedBox(width: 4),
                Text(
                  'Skills: $combinedSkills',
                  style: AppConstants.caption.copyWith(
                    color: AppConstants.vexIQOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (combinedSkills > 0 && avgTeamworkPoints > 0)
                const SizedBox(width: AppConstants.spacingM),
              if (avgTeamworkPoints > 0) ...[
                Icon(Icons.group_work, size: 16, color: AppConstants.vexIQGreen),
                const SizedBox(width: 4),
                Text(
                  'Teamwork Avg: ${avgTeamworkPoints.toStringAsFixed(1)}',
                  style: AppConstants.caption.copyWith(
                    color: AppConstants.vexIQGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
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
  Widget _buildResultsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub-tabs for Rankings and Awards (removed Skills to avoid duplication)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              labelColor: AppConstants.vexIQOrange,
              unselectedLabelColor: AppConstants.textSecondary,
              indicatorColor: AppConstants.vexIQOrange,
              tabs: const [
                Tab(text: 'Rankings', icon: Icon(Icons.format_list_numbered)),
                Tab(text: 'Awards', icon: Icon(Icons.emoji_events)),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                _buildRankingsView(),
                _buildAwardsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingsView() {
    return Column(
      children: [
        // Division selector for rankings (if multiple divisions)
        if (_divisions.length > 1)
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.group_work, color: AppConstants.vexIQBlue),
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
                      final divisionName = division['name'] ?? 'Division ${division['order'] ?? ''}';
                      
                      return DropdownMenuItem<int>(
                        value: divisionId,
                        child: Text(divisionName),
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
        
        // Rankings content
        Expanded(
          child: _buildRankingsContent(),
        ),
      ],
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
              color: AppConstants.textSecondary,
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
                color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Awards Available',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Awards will appear here once available',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
        final awardName = award['title']?.toString() ?? 'Unknown Award';
        final awardOrder = award['order']?.toString() ?? '';
        final teamData = award['team'];
        final teamNumber = (teamData is Map) 
            ? (teamData['name']?.toString() ?? 'Unknown Team')
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
                      ),
                    ],
                  ),
                ),
                
                // Award order/rank
                if (awardOrder.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingS,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.vexIQGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                    ),
                    child: Text(
                      awardOrder,
                      style: AppConstants.caption.copyWith(
                        color: AppConstants.vexIQGreen,
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
              color: AppConstants.textSecondary,
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
                color: AppConstants.textSecondary,
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
              Icons.emoji_events_outlined,
              size: 64,
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Skills Records',
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Skills rankings will appear here once available',
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Group skills by type and sort by score with proper type handling
    final driverSkills = _skills
        .where((skill) => skill['type'] == 'driver')
        .toList()
      ..sort((a, b) {
        final scoreA = (a['score'] is int) ? a['score'] as int : int.tryParse(a['score']?.toString() ?? '0') ?? 0;
        final scoreB = (b['score'] is int) ? b['score'] as int : int.tryParse(b['score']?.toString() ?? '0') ?? 0;
        return scoreB.compareTo(scoreA);
      });
    
    final autonomousSkills = _skills
        .where((skill) => skill['type'] == 'programming')
        .toList()
      ..sort((a, b) {
        final scoreA = (a['score'] is int) ? a['score'] as int : int.tryParse(a['score']?.toString() ?? '0') ?? 0;
        final scoreB = (b['score'] is int) ? b['score'] as int : int.tryParse(b['score']?.toString() ?? '0') ?? 0;
        return scoreB.compareTo(scoreA);
      });

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: TabBar(
              labelColor: AppConstants.vexIQGreen,
              unselectedLabelColor: AppConstants.textSecondary,
              indicatorColor: AppConstants.vexIQGreen,
              tabs: [
                Tab(text: 'Driver Skills (${driverSkills.length})'),
                Tab(text: 'Autonomous Skills (${autonomousSkills.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSkillsListView(driverSkills, 'Driver Skills'),
                _buildSkillsListView(autonomousSkills, 'Autonomous Skills'),
              ],
            ),
          ),
        ],
      ),
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No $skillType Records',
              style: AppConstants.bodyText1.copyWith(
                color: AppConstants.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
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

        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Row(
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
                      Row(
                        children: [
                          if (attempts > 0)
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
                                '$attempts tries',
                                style: AppConstants.caption.copyWith(
                                  color: AppConstants.vexIQBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (attempts > 0) const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppConstants.vexIQOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Rank $rank',
                              style: AppConstants.caption.copyWith(
                                color: AppConstants.vexIQOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingS,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Text(
                    '$score pts',
                    style: AppConstants.bodyText1.copyWith(
                      color: AppConstants.vexIQGreen,
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

  Widget _buildMatchCard(dynamic match) {
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
        color: AppConstants.vexIQBlue.withOpacity(0.05),
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
              color: AppConstants.textSecondary,
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
                     AppConstants.textSecondary,
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
        foregroundColor: Colors.white,
      ),
      body: matches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sports_esports_outlined,
                    size: 64,
                    color: AppConstants.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'No Matches Found',
                    style: AppConstants.headline6.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Matches will appear here once they are scheduled',
                    style: AppConstants.bodyText2.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                return _buildMatchCard(matches[index]);
              },
            ),
    );
  }

  Widget _buildMatchCard(dynamic match) {
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
        color: AppConstants.vexIQBlue.withOpacity(0.05),
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
                    color: AppConstants.textSecondary,
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
                     AppConstants.textSecondary,
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
} 