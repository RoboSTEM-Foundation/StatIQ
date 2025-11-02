import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/special_teams_service.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/screens/event_details_screen.dart';
// import 'package:stat_iq/services/vex_iq_scoring.dart';
import 'package:stat_iq/widgets/vex_iq_score_card.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:stat_iq/screens/settings_screen.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/widgets/optimized_team_search_widget.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Team> _favoriteTeams = [];
  List<Event> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadFavoriteTeams();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('first_launch') ?? true;
    final userSettings = Provider.of<UserSettings>(context, listen: false);

    if (isFirstLaunch && userSettings.myTeam == null) {
      _showMyTeamDialog();
      await prefs.setBool('first_launch', false);
    }
  }

  void _showMyTeamDialog() {
    Navigator.pushNamed(context, '/team-select');
  }

  Future<void> _loadFavoriteTeams() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userSettings = Provider.of<UserSettings>(context, listen: false);
      final favoriteTeamNumbers = userSettings.favoriteTeams;
      final favoriteEventSkus = userSettings.favoriteEvents;
      
      // Load favorite teams
      final teams = <Team>[];
      for (final teamNumber in favoriteTeamNumbers) {
        try {
          final searchResults = await RobotEventsAPI.searchTeams(teamNumber: teamNumber);
          final team = searchResults.isNotEmpty ? searchResults.first : null;
          if (team != null) {
            teams.add(team);
          }
        } catch (e) {
          print('Error loading team $teamNumber: $e');
        }
      }
      
      // Load favorite events
      final events = <Event>[];
      for (final eventSku in favoriteEventSkus) {
        try {
          final eventData = await RobotEventsAPI.getEventBySku(eventSku);
          if (eventData != null) {
            events.add(Event.fromJson(eventData));
          }
        } catch (e) {
          print('Error loading event $eventSku: $e');
        }
      }
      
      setState(() {
        _favoriteTeams = teams;
        _recentEvents = events;
      });
    } catch (e) {
      print('Error loading favorites: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getEventLocation(Event event) {
    final parts = <String>[];
    if (event.city.isNotEmpty) parts.add(event.city);
    if (event.region.isNotEmpty) parts.add(event.region);
    if (event.country.isNotEmpty) parts.add(event.country);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSettings>(
      builder: (context, userSettings, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('statIQ'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadFavoriteTeams,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    final userSettings = Provider.of<UserSettings>(context);
    final hasFavorites = _favoriteTeams.isNotEmpty || userSettings.favoriteEvents.isNotEmpty;
    
    if (!hasFavorites) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: AppConstants.spacingM,
        bottom: 100, // Account for bottom navigation
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_favoriteTeams.isNotEmpty) ...[
            _buildFavoriteTeamsSection(),
            const SizedBox(height: AppConstants.spacingL),
          ],
          if (userSettings.favoriteEvents.isNotEmpty) ...[
            _buildFavoriteEventsSection(),
            const SizedBox(height: AppConstants.spacingL),
          ],
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
                color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              'No Favorites',
              style: AppConstants.headline5.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              'Add teams and events to your favorites to see them here',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onNavigateToTab?.call(1); // Navigate to Teams tab
                  },
                  icon: const Icon(Icons.people),
                  label: const Text('Find Teams'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onNavigateToTab?.call(2); // Navigate to Events tab
                  },
                  icon: const Icon(Icons.event),
                  label: const Text('Find Events'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteEventsSection() {
    final userSettings = Provider.of<UserSettings>(context);
    final favoriteEventSkus = userSettings.favoriteEvents;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Events',
            style: AppConstants.headline5.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                children: [
                  Icon(
                    Icons.event,
                    color: AppConstants.vexIQBlue,
                    size: 32,
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    '${favoriteEventSkus.length} Favorite Event${favoriteEventSkus.length == 1 ? '' : 's'}',
                    style: AppConstants.headline6.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  if (_recentEvents.isNotEmpty) ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentEvents.length,
                      itemBuilder: (context, index) {
                        final event = _recentEvents[index];
                        return _buildEventCard(event);
                      },
                    ),
                  ] else ...[
                    Text(
                      'Loading favorite events...',
                      style: AppConstants.bodyText2.copyWith(
                        color: ThemeUtils.getSecondaryTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppConstants.spacingM),
                  ElevatedButton(
                    onPressed: () {
                      widget.onNavigateToTab?.call(3); // Navigate to Events tab
                    },
                    child: const Text('View All Events'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: ListTile(
        leading: const Icon(Icons.event, color: AppConstants.vexIQGreen),
        title: Text(
          event.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          event.location,
          style: TextStyle(
            color: ThemeUtils.getSecondaryTextColor(context),
          ),
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

  Widget _buildFavoriteTeamsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Teams',
            style: AppConstants.headline5.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _favoriteTeams.length,
            itemBuilder: (context, index) {
              final team = _favoriteTeams[index];
              return _buildTeamCard(team);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    return Consumer<UserSettings>(
      builder: (context, userSettings, child) {
        final isMyTeam = userSettings.myTeam == team.number;
        final teamTier = SpecialTeamsService.instance.getTeamTier(team.number);
        final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
        final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
          elevation: AppConstants.elevationS,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
            side: (isMyTeam || tierColor != null) ? BorderSide(
              color: tierColor ?? AppConstants.vexIQBlue,
              width: 2,
            ) : BorderSide.none,
          ),
          color: (isMyTeam || tierColor != null) 
              ? (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.1) 
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
            onTap: () => _showTeamDetails(team),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (isMyTeam || tierColor != null) 
                            ? (tierColor ?? AppConstants.vexIQBlue) 
                            : AppConstants.vexIQOrange,
                        radius: 24,
                        child: Text(
                          team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
                          style: AppConstants.bodyText1.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              team.number,
                              style: AppConstants.headline6.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (teamTier != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tierColor!.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                                  border: Border.all(color: tierColor, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.stars,
                                      size: 10,
                                      color: tierColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      SpecialTeamsService.instance.getTierDisplayName(teamTier),
                                      style: AppConstants.caption.copyWith(
                                        color: tierColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (team.name.isNotEmpty)
                          Text(
                            team.name,
                            style: AppConstants.bodyText1.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                        if (team.organization.isNotEmpty)
                          Text(
                            team.organization,
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingM),
                              // statIQ Score
                VEXIQScoreCard(
                  team: team,
                  seasonId: ApiConfig.getSelectedSeasonId(),
                ),
              const SizedBox(height: AppConstants.spacingS),
              // Team info
              Row(
                children: [
                  if (team.grade.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingS,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.vexIQBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                      ),
                      child: Text(
                        team.grade,
                        style: AppConstants.caption.copyWith(
                          color: AppConstants.vexIQBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                  ],
                  if (team.city.isNotEmpty && team.region.isNotEmpty)
                    Expanded(
                      child: Text(
                        '${team.city}, ${team.region}',
                        style: AppConstants.caption.copyWith(
                          color: ThemeUtils.getSecondaryTextColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  void _showTeamDetails(Team team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailsScreen(team: team),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppConstants.headline6.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Search Teams',
                  Icons.people,
                  AppConstants.vexIQBlue,
                  () => widget.onNavigateToTab?.call(2),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: _buildActionCard(
                  'Browse Events',
                  Icons.event,
                  AppConstants.vexIQGreen,
                  () => widget.onNavigateToTab?.call(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              title,
              style: AppConstants.bodyText2.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamDetailsBottomSheet extends StatefulWidget {
  final Team team;

  const _TeamDetailsBottomSheet({required this.team});

  @override
  State<_TeamDetailsBottomSheet> createState() => _TeamDetailsBottomSheetState();
}

class _TeamDetailsBottomSheetState extends State<_TeamDetailsBottomSheet> {
  bool _isLoading = true;
  List<Event> _teamEvents = [];
  List<dynamic> _teamAwards = [];

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await RobotEventsAPI.getTeamEvents(teamId: widget.team.id);
      final awards = await RobotEventsAPI.getTeamAwards(teamId: widget.team.id);
      
      setState(() {
        _teamEvents = events;
        _teamAwards = awards;
      });
    } catch (e) {
      print('Error loading team data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getEventLocation(Event event) {
    final parts = <String>[];
    if (event.city.isNotEmpty) parts.add(event.city);
    if (event.region.isNotEmpty) parts.add(event.region);
    if (event.country.isNotEmpty) parts.add(event.country);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: ThemeUtils.getVeryMutedTextColor(context, opacity: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppConstants.vexIQOrange,
                  radius: 20,
                  child: Text(
                    widget.team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
                    style: AppConstants.bodyText2.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.team.number,
                        style: AppConstants.headline6.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.team.name.isNotEmpty)
                        Text(
                          widget.team.name,
                          style: AppConstants.bodyText2.copyWith(
                            color: ThemeUtils.getSecondaryTextColor(context),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'Competitions'),
                            Tab(text: 'Awards'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildEventsTab(),
                              _buildAwardsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    if (_teamEvents.isEmpty) {
      return const Center(
        child: Text('No competitions found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _teamEvents.length,
      itemBuilder: (context, index) {
        final event = _teamEvents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: ListTile(
            leading: Icon(
              Icons.event,
              color: AppConstants.vexIQBlue,
            ),
            title: Text(event.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getEventLocation(event)),
                if (event.start != null)
                  Text(
                    '${event.start!.day}/${event.start!.month}/${event.start!.year}',
                    style: AppConstants.caption,
                  ),
              ],
            ),
            isThreeLine: true,
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
      },
    );
  }

  Widget _buildAwardsTab() {
    if (_teamAwards.isEmpty) {
      return const Center(
        child: Text('No awards found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _teamAwards.length,
      itemBuilder: (context, index) {
        final awardData = _teamAwards[index] as Map<String, dynamic>;
        final awardTitle = awardData['title'] as String? ?? 'Unknown Award';
        return Card(
          margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
          child: ListTile(
            leading: Icon(
              Icons.emoji_events,
              color: AppConstants.vexIQOrange,
            ),
            title: Text(awardTitle),
          ),
        );
      },
    );
  }
} 