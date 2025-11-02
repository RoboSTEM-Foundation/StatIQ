import 'package:flutter/material.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/special_teams_service.dart';
import 'package:stat_iq/widgets/vex_iq_score_card.dart';
import 'package:stat_iq/constants/app_constants.dart';
// import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/screens/event_details_screen.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;
  final int? eventId; // Optional event ID to filter matches (Bug Patch 3 requirement)

  const TeamDetailsScreen({
    super.key,
    required this.team,
    this.eventId,
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
    _tabController = TabController(length: 4, vsync: this);
    _loadTeamData(    );
  }

  String _getEventNameForMatch(Match match) {
    // Try to find event information from team events
    if (_currentTeam != null && _teamEvents.isNotEmpty) {
      // If we have a specific event ID, return that event's name
      if (widget.eventId != null) {
        final specificEvent = _teamEvents.firstWhere(
          (event) => event.id == widget.eventId,
          orElse: () => _teamEvents.first,
        );
        return specificEvent.name;
      }
      
      // For matches from all events, try to match by date proximity
      if (match.scheduled != null) {
        Event? closestEvent;
        int minDaysDiff = 365; // Start with a large number
        
        for (final event in _teamEvents) {
          if (event.start != null) {
            final daysDiff = (match.scheduled!.difference(event.start!).inDays).abs();
            if (daysDiff < minDaysDiff) {
              minDaysDiff = daysDiff;
              closestEvent = event;
            }
          }
        }
        
        if (closestEvent != null && minDaysDiff <= 7) {
          return closestEvent.name; // Only use if within a week
        }
      }
      
      // Fallback: use the first event
      return _teamEvents.first.name;
    }
    return 'Unknown Event';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Team? _currentTeam;
  
  Future<void> _loadTeamData() async {
    // If team ID is 0 or invalid, try to find the team by number first
    if (widget.team.id == 0 && widget.team.number.isNotEmpty) {
      try {
        print('🔍 Team ID is 0, searching for team by number: ${widget.team.number}');
        final searchResults = await RobotEventsAPI.searchTeams(teamNumber: widget.team.number);
        if (searchResults.isNotEmpty) {
          final foundTeam = searchResults.first;
          print('✅ Found team with ID: ${foundTeam.id}');
          // Use the found team with proper ID
          _currentTeam = foundTeam;
        } else {
          print('⚠️ No team found with number: ${widget.team.number}');
          _currentTeam = widget.team;
        }
      } catch (e) {
        print('❌ Error searching for team: $e');
        _currentTeam = widget.team;
      }
    } else {
      _currentTeam = widget.team;
    }
    
    await _loadTeamEvents();
    await Future.wait([
      _loadTeamAwards(),
      _loadCompetitionData(),
    ]);
  }

  Future<void> _loadTeamEvents() async {
    try {
      final teamId = _currentTeam?.id ?? widget.team.id;
      final events = await RobotEventsAPI.getTeamEvents(
        teamId: teamId,
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
        teamId: _currentTeam?.id ?? widget.team.id,
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
      if (_currentTeam == null) {
        if (mounted) {
          setState(() {
            _isLoadingCompetitionData = false;
          });
        }
        return;
      }

      // Use the new direct team matches API (Bug Patch 3 requirement)
      final matchesData = await RobotEventsAPI.getTeamMatches(
        teamId: _currentTeam!.id,
        seasonId: _selectedSeasonId,
        eventIds: widget.eventId != null ? [widget.eventId!] : null, // Filter by event if provided, null means all events
      );

      final allMatches = <Match>[];
      for (final matchData in matchesData) {
        try {
          final match = Match.fromJson(matchData as Map<String, dynamic>);
          allMatches.add(match);
        } catch (e) {
          print('Error parsing match data: $e');
        }
      }

      // Sort matches by scheduled time (earliest first)
      allMatches.sort((a, b) {
        if (a.scheduled == null && b.scheduled == null) return 0;
        if (a.scheduled == null) return 1;
        if (b.scheduled == null) return -1;
        return a.scheduled!.compareTo(b.scheduled!);
      });

      if (mounted) {
        setState(() {
          _teamMatches = allMatches;
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
        _selectedSeason = 'Rapid Relay';
        _selectedSeasonId = 189; // Rapid Relay season ID (has data)
      } else {
        _selectedSeason = 'Mix & Match';
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
    final teamTier = SpecialTeamsService.instance.getTeamTier((_currentTeam ?? widget.team).number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (_currentTeam ?? widget.team).number,
              style: AppConstants.headline6.copyWith(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if ((_currentTeam ?? widget.team).name.isNotEmpty)
              Text(
                (_currentTeam ?? widget.team).name,
                style: AppConstants.caption.copyWith(
                  color: Theme.of(context).iconTheme.color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
          ],
        ),
        actions: [
          _buildSeasonSelector(),
            IconButton(
              icon: Icon(Icons.share, color: Theme.of(context).iconTheme.color),
              onPressed: () => _shareTeam(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: tierColor ?? AppConstants.vexIQBlue,
          labelColor: tierColor ?? AppConstants.vexIQBlue,
          unselectedLabelColor: ThemeUtils.getSecondaryTextColor(context, opacity: 0.6),
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Competitions'),
            const Tab(text: 'Awards'),
            Tab(text: widget.eventId != null ? 'Event Matches' : 'Matches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildCompetitionsTab(),
          _buildAwardsTab(),
          _buildMatchesTab(),
        ],
      ),
    );
  }

  Widget _buildMatchesTab() {
    final teamTier = SpecialTeamsService.instance.getTeamTier((_currentTeam ?? widget.team).number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
    if (_isLoadingCompetitionData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamMatches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videogame_asset_off_outlined,
                size: 64,
                color: ThemeUtils.getVeryMutedTextColor(context),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'No Skills Matches Found',
                style: AppConstants.headline6.copyWith(
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                widget.eventId != null 
                    ? 'No skills challenge data is available for this team at this specific event.'
                    : 'No skills challenge data is available for this team in the $_selectedSeason season.',
                style: AppConstants.bodyText2.copyWith(
                  color: Theme.of(context).iconTheme.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (widget.eventId == null) {
      // Group matches by event when showing all competitions
      final matchesByEvent = <String, List<Match>>{};
      for (final match in _teamMatches) {
        final eventName = _getEventNameForMatch(match);
        matchesByEvent.putIfAbsent(eventName, () => []).add(match);
      }

      // Sort events by name for consistent ordering
      final sortedEvents = matchesByEvent.keys.toList()..sort();
      
      return ListView.builder(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        itemCount: sortedEvents.length,
        itemBuilder: (context, eventIndex) {
          final eventName = sortedEvents[eventIndex];
          final eventMatches = matchesByEvent[eventName]!;
          
          // Sort matches within each event by date (earliest first)
          eventMatches.sort((a, b) {
            if (a.scheduled == null && b.scheduled == null) return 0;
            if (a.scheduled == null) return 1;
            if (b.scheduled == null) return -1;
            return a.scheduled!.compareTo(b.scheduled!);
          });
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                margin: EdgeInsets.only(
                  top: eventIndex > 0 ? AppConstants.spacingL : 0.0,
                  bottom: AppConstants.spacingS,
                ),
                decoration: BoxDecoration(
                  color: (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 16,
                      color: tierColor ?? AppConstants.vexIQBlue,
                    ),
                    const SizedBox(width: AppConstants.spacingXS),
                    Expanded(
                      child: Text(
                        eventName,
                        style: AppConstants.bodyText2.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tierColor ?? AppConstants.vexIQBlue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${eventMatches.length} ${eventMatches.length == 1 ? 'match' : 'matches'}',
                        style: AppConstants.caption.copyWith(
                          color: tierColor ?? AppConstants.vexIQBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Matches for this event
              ...eventMatches.map((match) => _buildMatchCard(match)).toList(),
            ],
          );
        },
      );
    } else {
      // Show single event matches (current implementation)
      return ListView.builder(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        itemCount: _teamMatches.length,
        itemBuilder: (context, index) {
          final match = _teamMatches[index];
          return _buildMatchCard(match);
        },
      );
    }
  }

  String _getMatchTypeDisplay(Match match) {
    final name = match.name.toLowerCase();
    
    // Extract number from match name
    final numberMatch = RegExp(r'#(\d+)').firstMatch(match.name);
    final matchNumber = numberMatch?.group(1) ?? '??';
    
    if (name.contains('final')) {
      return 'F $matchNumber';
    } else {
      return 'Q $matchNumber';
    }
  }

  Widget _buildTeamPill(String teamNumber, bool isCurrentTeam) {
    final teamTier = SpecialTeamsService.instance.getTeamTier(teamNumber);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentTeam 
            ? (tierColor ?? AppConstants.vexIQBlue)
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        teamNumber,
        style: TextStyle(
          color: isCurrentTeam ? Colors.white : Colors.black87,
          fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildMatchCard(Match match) {
    final teamTier = SpecialTeamsService.instance.getTeamTier((_currentTeam ?? widget.team).number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
    // For VEX IQ, matches are skills challenges, not head-to-head competitions
    // Find which alliance the team is in and get all teams in the match
    String teamAlliance = '';
    int teamScore = 0;
    List<Team> allTeamsInMatch = [];
    
    for (final alliance in match.alliances) {
      allTeamsInMatch.addAll(alliance.teams);
      final hasTeam = alliance.teams.any((team) => team.id == _currentTeam?.id);
      if (hasTeam) {
        teamAlliance = alliance.color;
        teamScore = alliance.score;
      }
    }

    final matchType = _getMatchTypeDisplay(match);
    final formattedTime = match.scheduled != null ? _formatCompactTime(match.scheduled!) : '';
    final eventName = _getEventNameForMatch(match);
    
    // Find the event for this match
    Event? eventForMatch;
    if (widget.eventId != null) {
      eventForMatch = _teamEvents.firstWhere(
        (e) => e.id == widget.eventId,
        orElse: () => _teamEvents.first,
      );
    } else if (match.scheduled != null) {
      // Find closest event by date
      Event? closestEvent;
      int minDaysDiff = 365;
      for (final event in _teamEvents) {
        if (event.start != null) {
          final daysDiff = (match.scheduled!.difference(event.start!).inDays).abs();
          if (daysDiff < minDaysDiff) {
            minDaysDiff = daysDiff;
            closestEvent = event;
          }
        }
      }
      eventForMatch = (closestEvent != null && minDaysDiff <= 7) ? closestEvent : _teamEvents.isNotEmpty ? _teamEvents.first : null;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      color: Theme.of(context).brightness == Brightness.dark 
          ? Colors.grey[800]!.withOpacity(0.3)
          : (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.05),
      child: InkWell(
        onTap: eventForMatch != null ? () {
          // Navigate to event details screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsScreen(event: eventForMatch!),
            ),
          );
        } : null,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Row(
            children: [
              // Left side: Match type and teams
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Match type and date/time
                    Row(
                      children: [
                        Text(
                          matchType,
                          style: AppConstants.bodyText1.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (match.scheduled != null)
                          Text(
                            '${match.scheduled!.month.toString().padLeft(2, '0')}/${match.scheduled!.day.toString().padLeft(2, '0')}/${(match.scheduled!.year % 100).toString().padLeft(2, '0')} · $formattedTime',
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Team pills in row
                    if (allTeamsInMatch.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: allTeamsInMatch.map((team) {
                          final isCurrentTeam = team.id == _currentTeam?.id;
                          return _buildTeamPill(team.number, isCurrentTeam);
                        }).toList(),
                      ),
                    if (eventName.isNotEmpty && eventName != 'Unknown Event') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 14,
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              eventName,
                              style: AppConstants.caption.copyWith(
                                color: tierColor ?? AppConstants.vexIQBlue,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Score and arrow
              Column(
                children: [
                  Text(
                    teamScore.toString(),
                    style: AppConstants.headline4.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (matchDate == today) {
      return 'Today at ${_formatTime(dateTime)}';
    } else if (matchDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    } else if (matchDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatCompactTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Widget _buildSeasonSelector() {
    return PopupMenuButton<bool>(
        icon: Icon(Icons.calendar_today, color: Theme.of(context).iconTheme.color),
      tooltip: 'Select Season',
      onSelected: _onSeasonChanged,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: false,
          child: Row(
            children: [
              Icon(
                Icons.fiber_new,
                color: _usePreviousSeason ? ThemeUtils.getSecondaryTextColor(context) : AppConstants.vexIQBlue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Mix & Match',
                style: TextStyle(
                  color: _usePreviousSeason ? ThemeUtils.getSecondaryTextColor(context) : AppConstants.vexIQBlue,
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
                color: _usePreviousSeason ? AppConstants.vexIQBlue : ThemeUtils.getSecondaryTextColor(context),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Rapid Relay',
                style: TextStyle(
                  color: _usePreviousSeason ? AppConstants.vexIQBlue : ThemeUtils.getSecondaryTextColor(context),
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
    final teamTier = SpecialTeamsService.instance.getTeamTier((_currentTeam ?? widget.team).number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    final tierDescription = teamTier != null ? SpecialTeamsService.instance.getTierDescription(teamTier) : null;
    final tierDisplayName = teamTier != null ? SpecialTeamsService.instance.getTierDisplayName(teamTier) : null;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Special Team Banner (if applicable)
          if (teamTier != null && tierColor != null) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
                side: BorderSide(color: tierColor, width: 2),
              ),
              color: tierColor.withOpacity(0.15),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                child: Row(
                  children: [
                    Icon(
                      Icons.stars,
                      color: tierColor,
                      size: 28,
                    ),
                    const SizedBox(width: AppConstants.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tierDisplayName ?? teamTier,
                            style: AppConstants.headline6.copyWith(
                              color: tierColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (tierDescription != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              tierDescription,
                              style: AppConstants.bodyText2.copyWith(
                                color: ThemeUtils.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
          ],
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
    final teamTier = SpecialTeamsService.instance.getTeamTier((_currentTeam ?? widget.team).number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
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
                    color: (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: tierColor ?? AppConstants.vexIQBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_currentTeam ?? widget.team).name.isNotEmpty ? (_currentTeam ?? widget.team).name : 'Team ${(_currentTeam ?? widget.team).number}',
                        style: AppConstants.headline6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      if ((_currentTeam ?? widget.team).robotName.isNotEmpty)
                        Text(
                          'Robot: ${(_currentTeam ?? widget.team).robotName}',
                          style: AppConstants.bodyText2.copyWith(
                            color: Theme.of(context).iconTheme.color,
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
            _buildInfoRow(Icons.school, 'Organization', (_currentTeam ?? widget.team).organization),
            _buildInfoRow(Icons.location_on, 'Location', _getTeamLocation()),
            _buildInfoRow(Icons.grade, 'Grade Level', (_currentTeam ?? widget.team).grade),
            _buildInfoRow(
              (_currentTeam ?? widget.team).registered ? Icons.check_circle : Icons.radio_button_unchecked,
              'Registration Status',
              (_currentTeam ?? widget.team).registered ? 'Registered' : 'Not Registered',
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
            color: Theme.of(context).iconTheme.color,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Text(
            '$label: ',
            style: AppConstants.bodyText2.copyWith(
              color: Theme.of(context).iconTheme.color,
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
    final teamTier = SpecialTeamsService.instance.getTeamTier((_currentTeam ?? widget.team).number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
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
                    tierColor ?? AppConstants.vexIQBlue,
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
            color: Theme.of(context).iconTheme.color,
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
                  ? 'This is data from the previous season (Rapid Relay)'
                  : 'This is data from the current season (Mix & Match)',
              style: AppConstants.bodyText2.copyWith(
                color: Theme.of(context).iconTheme.color,
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
                color: ThemeUtils.getVeryMutedTextColor(context),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'No Competitions Found',
                style: AppConstants.headline6.copyWith(
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'This team hasn\'t participated in any VEX IQ competitions in the $_selectedSeason season yet.',
                style: AppConstants.bodyText2.copyWith(
                  color: Theme.of(context).iconTheme.color,
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
                          color: Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: Text(
                            _getEventLocation(event),
                            style: AppConstants.bodyText2.copyWith(
                              color: Theme.of(context).iconTheme.color,
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
                          color: Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          '${event.start!.day}/${event.start!.month}/${event.start!.year}',
                          style: AppConstants.bodyText2.copyWith(
                            color: Theme.of(context).iconTheme.color,
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
                          color: Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(
                          event.sku,
                          style: AppConstants.caption.copyWith(
                            color: Theme.of(context).iconTheme.color,
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
                color: ThemeUtils.getVeryMutedTextColor(context),
              ),
              const SizedBox(height: AppConstants.spacingM),
              Text(
                'No Awards Found',
                style: AppConstants.headline6.copyWith(
                  color: Theme.of(context).iconTheme.color,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'This team hasn\'t won any awards in the $_selectedSeason season yet.',
                style: AppConstants.bodyText2.copyWith(
                  color: Theme.of(context).iconTheme.color,
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
        final eventData = awardData['event'];
        final eventName = (eventData is Map) 
            ? (eventData['name']?.toString() ?? 'Unknown Event')
            : 'Unknown Event';
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
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
                const SizedBox(height: AppConstants.spacingS),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 16,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        eventName,
                        style: AppConstants.bodyText2.copyWith(
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTeamLocation() {
    final team = _currentTeam ?? widget.team;
    final parts = <String>[];
    if (team.city.isNotEmpty) parts.add(team.city);
    if (team.region.isNotEmpty) parts.add(team.region);
    if (team.country.isNotEmpty) parts.add(team.country);
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
        content: Text('Sharing ${(_currentTeam ?? widget.team).number} - ${(_currentTeam ?? widget.team).name}'),
        backgroundColor: AppConstants.vexIQBlue,
      ),
    );
  }
} 