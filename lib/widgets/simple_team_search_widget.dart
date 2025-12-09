import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/team_sync_service.dart';
import 'package:stat_iq/services/simple_team_search.dart';
import 'package:stat_iq/services/special_teams_service.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'dart:async';

class SimpleTeamSearchWidget extends StatefulWidget {
  final String? hintText;
  final bool showSyncStatus;
  final Function(Team)? onTeamSelected;
  final bool useAPI; // New parameter to use API instead of cached data

  const SimpleTeamSearchWidget({
    super.key,
    this.hintText,
    this.showSyncStatus = false,
    this.onTeamSelected,
    this.useAPI = false,
  });

  @override
  State<SimpleTeamSearchWidget> createState() => _SimpleTeamSearchWidgetState();
}

class _SimpleTeamSearchWidgetState extends State<SimpleTeamSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  Timer? _debouncer;
  bool _hasData = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadDataAsync();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debouncer?.cancel();
    super.dispose();
  }

  Future<void> _loadDataAsync() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.useAPI) {
        // When using API, we don't need to initialize cached data
        print('📱 Using API search mode');
        setState(() {
          _hasData = true;
          _isLoading = false;
        });
      } else {
        // Initialize simple search with cached data
      await SimpleTeamSearch.initialize();
      
      if (mounted) {
        final hasData = SimpleTeamSearch.isReady();
        final teamCount = SimpleTeamSearch.getTeamCount();
        print('📱 Search initialized: hasData=$hasData, teamCount=$teamCount');
        
        setState(() {
          _hasData = hasData;
          _isLoading = false;
        });
        
        // Show first 20 teams by default
        _performSearch('');
        }
      }
    } catch (e) {
      print('❌ Error loading search data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 100), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    if (!_hasData) {
      print('❌ No data available for search');
      return;
    }
    
    setState(() {
      _isSearching = true;
    });

    if (widget.useAPI) {
      // Use API search (async)
      _performAPISearch(query);
    } else {
      // Use cached simple search
    if (query.trim().isEmpty) {
      // Show first 20 teams when no search
      _searchResults = SimpleTeamSearch.getFirstTeams(20);
      print('📱 Showing first 20 teams: ${_searchResults.length} results');
    } else {
      // Search by team number (fastest)
      _searchResults = SimpleTeamSearch.searchByNumber(query, limit: 50);
      print('🔍 Search for "$query": ${_searchResults.length} results');
    }
    
    setState(() {
      _isSearching = false;
    });
    }
  }

  Future<void> _performAPISearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    try {
      final results = await SimpleTeamSearch.searchByAPI(query, limit: 50);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('❌ API search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _refreshTeamList() async {
    setState(() {
      _isLoading = true;
    });
    
    await TeamSyncService.syncTeamList();
    await SimpleTeamSearch.initialize();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasData = SimpleTeamSearch.isReady();
      });
      _performSearch(_searchController.text);
    }
  }

  void _onTeamTap(Map<String, dynamic> teamData) {
    final team = Team(
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

    if (widget.onTeamSelected != null) {
      widget.onTeamSelected!(team);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeamDetailsScreen(team: team),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        _buildSearchBar(),

        // Sync status (optional)
        if (widget.showSyncStatus) _buildSyncStatus(),

        // Search results
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search by team number (e.g., 2A, 14G)...',
          hintStyle: AppConstants.bodyText2.copyWith(
            color: ThemeUtils.getSecondaryTextColor(context),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: ThemeUtils.getSecondaryTextColor(context),
          ),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Theme.of(context).iconTheme.color),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingM,
          ),
        ),
        style: AppConstants.bodyText1,
      ),
    );
  }

  Widget _buildSyncStatus() {
    return FutureBuilder<Map<String, dynamic>>(
      future: TeamSyncService.getSyncStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final status = snapshot.data!;
        final teamCount = status['teamCount'] as int;
        final needsSync = status['needsSync'] as bool;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          padding: const EdgeInsets.all(AppConstants.spacingS),
          decoration: BoxDecoration(
            color: teamCount == 0 ? Colors.blue.withOpacity(0.1) : (needsSync ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
            border: Border.all(
              color: teamCount == 0 ? Colors.blue : (needsSync ? Colors.orange : Colors.green),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                teamCount == 0 ? Icons.info : (needsSync ? Icons.sync_problem : Icons.sync),
                color: teamCount == 0 ? Colors.blue : (needsSync ? Colors.orange : Colors.green),
                size: 16,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  teamCount == 0
                      ? 'Team list not available yet. GitHub Action needs to run first.'
                      : (needsSync
                          ? 'Team list needs update ($teamCount teams cached)'
                          : 'Team list up to date ($teamCount teams)'),
                  style: AppConstants.caption.copyWith(
                    color: teamCount == 0 ? Colors.blue : (needsSync ? Colors.orange : Colors.green),
                  ),
                ),
              ),
              if (needsSync && teamCount > 0)
                TextButton(
                  onPressed: _isLoading ? null : _refreshTeamList,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasData) {
      return _buildEmptyState(
        icon: Icons.download,
        title: 'Loading Team List',
        message: 'Downloading team data...',
        actionButton: TextButton(
          onPressed: _isLoading ? null : _refreshTeamList,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Refresh'),
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No Teams Found',
        message: 'Try a different team number or check the spelling.',
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group,
        title: 'No Teams Available',
        message: 'Team data is not loaded yet.',
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final teamData = _searchResults[index];
        final team = Team(
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

        final teamTier = SpecialTeamsService.instance.getTeamTier(team.number);
        final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
        final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          elevation: AppConstants.elevationS,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
            side: tierColor != null ? BorderSide(color: tierColor, width: 2) : BorderSide.none,
          ),
          color: tierColor != null ? tierColor.withOpacity(0.1) : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
            onTap: () => _onTeamTap(teamData),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tierColor ?? AppConstants.vexIQOrange,
                    radius: 20,
                    child: Text(
                      team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
                      style: AppConstants.bodyText1.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
                            style: AppConstants.bodyText2.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (team.organization.isNotEmpty)
                          Text(
                            team.organization,
                            style: AppConstants.caption.copyWith(
                              color: ThemeUtils.getSecondaryTextColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Consumer<UserSettings>(
                    builder: (context, settings, child) {
                      final isFavorite = settings.isFavoriteTeam(team.number);
                      return IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Theme.of(context).iconTheme.color,
                          size: 20,
                        ),
                        onPressed: () async {
                          if (isFavorite) {
                            await settings.removeFavoriteTeam(team.number);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${team.number} removed from favorites')),
                              );
                            }
                          } else {
                            await settings.addFavoriteTeam(team.number);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${team.number} added to favorites')),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: ThemeUtils.getSecondaryTextColor(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? actionButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: ThemeUtils.getVeryMutedTextColor(context),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              title,
              style: AppConstants.headline6.copyWith(
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              message,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionButton != null) ...[
              const SizedBox(height: AppConstants.spacingM),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}
