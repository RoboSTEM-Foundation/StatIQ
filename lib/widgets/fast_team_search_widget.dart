import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/team_sync_service.dart';
import 'package:stat_iq/services/team_search_service.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/utils/logger.dart';
import 'dart:async';

class FastTeamSearchWidget extends StatefulWidget {
  final String? hintText;
  final bool showSyncStatus;
  final Function(Team)? onTeamSelected;

  const FastTeamSearchWidget({
    super.key,
    this.hintText,
    this.showSyncStatus = false,
    this.onTeamSelected,
  });

  @override
  State<FastTeamSearchWidget> createState() => _FastTeamSearchWidgetState();
}

class _FastTeamSearchWidgetState extends State<FastTeamSearchWidget> {
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
    // Load data in background without blocking UI
    try {
      await TeamSearchService.initializeSearchIndexes();
      if (mounted) {
        setState(() {
          _hasData = true;
        });
        _performSearch(_searchController.text);
      }
    } catch (e) {
      AppLogger.d('Error loading search data: $e');
    }
  }

  void _onSearchChanged() {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 200), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    if (!_hasData) return;
    
    setState(() {
      _isSearching = true;
    });

    // Use optimized search with limited results for performance
    _searchResults = TeamSearchService.searchTeams(query, limit: 100);
    
    setState(() {
      _isSearching = false;
    });
  }

  Future<void> _refreshTeamList() async {
    setState(() {
      _isLoading = true;
    });
    
    await TeamSyncService.syncTeamList();
    await TeamSearchService.initializeSearchIndexes();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasData = true;
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
          hintText: widget.hintText ?? 'Search teams by number...',
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
    if (!_hasData) {
      return _buildEmptyState(
        icon: Icons.download,
        title: 'Loading Team List',
        message: 'Downloading team data in the background...',
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
        message: 'Try a different search term or check the spelling.',
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group,
        title: 'Search Teams',
        message: 'Start typing a team number to search.',
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

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: AppConstants.spacingS,
          ),
          elevation: AppConstants.elevationS,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
            onTap: () => _onTeamTap(teamData),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppConstants.vexIQOrange,
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
                        Text(
                          team.number,
                          style: AppConstants.headline6.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
