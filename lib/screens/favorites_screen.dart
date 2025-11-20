import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/special_teams_service.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:stat_iq/utils/theme_utils.dart';
// import 'package:stat_iq/screens/event_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Team> _favoriteTeamsData = [];
  List<Map<String, dynamic>> _favoriteEventsData = [];
  bool _isLoadingTeams = true;
  bool _isLoadingEvents = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavoriteData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteData() async {
    await Future.wait([
      _loadFavoriteTeams(),
      _loadFavoriteEvents(),
    ]);
  }

  Future<void> _loadFavoriteTeams() async {
    setState(() {
      _isLoadingTeams = true;
    });

    try {
      final userSettings = await UserSettings.getInstance();
      final favoriteTeamNumbers = userSettings.favoriteTeams;
      
      List<Team> teams = [];
      for (final teamNumber in favoriteTeamNumbers) {
        try {
          // Try to get team data from RobotEvents API
          final teamData = await RobotEventsAPI.getTeamByNumber(teamNumber);
          if (teamData != null) {
            teams.add(teamData);
          }
        } catch (e) {
          print('Error loading team $teamNumber: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _favoriteTeamsData = teams;
          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      print('Error loading favorite teams: $e');
      if (mounted) {
        setState(() {
          _isLoadingTeams = false;
        });
      }
    }
  }

  Future<void> _loadFavoriteEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final userSettings = await UserSettings.getInstance();
      final favoriteEventSkus = userSettings.favoriteEvents;
      
      List<Map<String, dynamic>> events = [];
      for (final eventSku in favoriteEventSkus) {
        try {
          // Try to get event data from RobotEvents API
          final eventData = await RobotEventsAPI.getEventBySku(eventSku);
          if (eventData != null) {
            events.add(eventData);
          }
        } catch (e) {
          print('Error loading event $eventSku: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _favoriteEventsData = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      print('Error loading favorite events: $e');
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSettings>(
      builder: (context, userSettings, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Favorites'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Teams',
                ),
                Tab(
                  icon: Icon(Icons.event),
                  text: 'Events',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildFavoriteTeamsTab(),
              _buildFavoriteEventsTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoriteTeamsTab() {
    if (_isLoadingTeams) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favoriteTeamsData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'No Favorite Teams',
        subtitle: 'Teams you favorite will appear here',
        actionText: 'Browse Teams',
        onAction: () {
          // TODO: Navigate to teams screen
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavoriteTeams,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        itemCount: _favoriteTeamsData.length,
        itemBuilder: (context, index) {
          final team = _favoriteTeamsData[index];
          return _buildFavoriteTeamCard(team);
        },
      ),
    );
  }

  Widget _buildFavoriteEventsTab() {
    if (_isLoadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favoriteEventsData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_busy,
        title: 'No Favorite Events',
        subtitle: 'Events you favorite will appear here',
        actionText: 'Browse Events',
        onAction: () {
          // Navigate to events screen (tab index 3)
          // This would need to be passed from the parent widget
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavoriteEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        itemCount: _favoriteEventsData.length,
        itemBuilder: (context, index) {
          final event = _favoriteEventsData[index];
          return _buildFavoriteEventCard(event);
        },
      ),
    );
  }

  Widget _buildFavoriteTeamCard(Team team) {
    final teamTier = SpecialTeamsService.instance.getTeamTier(team.number);
    final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
    final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
        side: tierColor != null ? BorderSide(color: tierColor, width: 2) : BorderSide.none,
      ),
      color: tierColor != null ? tierColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tierColor ?? _getDivisionColor(team.grade),
          child: Text(
            team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
            style: const TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
          team.name.isNotEmpty ? team.name : 'Team ${team.number}',
          style: AppConstants.headline6.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team ${team.number} • ${team.grade}',
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
            if (team.organization.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingXS),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                  const SizedBox(width: AppConstants.spacingXS),
                  Expanded(
                    child: Text(
                      team.organization,
                      style: AppConstants.caption.copyWith(
                        color: ThemeUtils.getSecondaryTextColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.favorite,
                color: AppConstants.vexIQRed,
              ),
              onPressed: () async {
                final userSettings = await UserSettings.getInstance();
                await userSettings.removeFavoriteTeam(team.number);
                await _loadFavoriteTeams(); // Reload the list
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamDetailsScreen(team: team),
                  ),
                );
              },
            ),
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
  }

  Widget _buildFavoriteEventCard(Map<String, dynamic> event) {
    final eventName = event['name']?.toString() ?? 'Unknown Event';
    final eventSku = event['sku']?.toString() ?? '';
    final eventDate = event['date']?.toString() ?? '';
    final eventLocation = event['location']?.toString() ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppConstants.vexIQBlue,
          child: Icon(
            Icons.event,
            color: Colors.white,
          ),
        ),
        title: Text(
          eventName,
          style: AppConstants.headline6.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eventDate.isNotEmpty)
              Text(
                eventDate,
                style: AppConstants.bodyText2.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              ),
            if (eventLocation.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingXS),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                  const SizedBox(width: AppConstants.spacingXS),
                  Expanded(
                    child: Text(
                      eventLocation,
                      style: AppConstants.caption.copyWith(
                        color: ThemeUtils.getSecondaryTextColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.favorite,
                color: AppConstants.vexIQRed,
              ),
              onPressed: () async {
                final userSettings = await UserSettings.getInstance();
                await userSettings.removeFavoriteEvent(eventSku);
                await _loadFavoriteEvents(); // Reload the list
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                // TODO: Navigate to event details when Event model is available
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => EventDetailsScreen(event: event),
                //   ),
                // );
              },
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to event details when Event model is available
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              title,
              style: AppConstants.headline5.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              subtitle,
              style: AppConstants.bodyText1.copyWith(
                color: ThemeUtils.getMutedTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingL),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.search),
              label: Text(actionText),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDivisionColor(String division) {
    switch (division.toLowerCase()) {
      case 'elementary school':
        return AppConstants.vexIQGreen;
      case 'middle school':
        return AppConstants.vexIQBlue;
      default:
        return AppConstants.vexIQOrange;
    }
  }
} 