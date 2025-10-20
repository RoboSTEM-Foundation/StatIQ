import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/team_sync_service.dart';
import 'package:stat_iq/services/team_search_service.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'dart:async';

class OptimizedTeamSearchWidget extends StatefulWidget {
  final String? hintText;
  final bool showSyncStatus;
  final Function(Team)? onTeamSelected;

  const OptimizedTeamSearchWidget({
    super.key,
    this.hintText,
    this.showSyncStatus = false,
    this.onTeamSelected,
  });

  @override
  State<OptimizedTeamSearchWidget> createState() => _OptimizedTeamSearchWidgetState();
}

class _OptimizedTeamSearchWidgetState extends State<OptimizedTeamSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  int _displayedCount = 0;
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debouncer;
  bool _searchIndexesReady = false;

  final int _loadIncrement = 50; // Number of teams to load at a time

  @override
  void initState() {
    super.initState();
    _initializeSearch();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debouncer?.cancel();
    super.dispose();
  }

  Future<void> _initializeSearch() async {
    setState(() {
      _isLoading = true;
    });

    // Try to load cached search indexes first
    await TeamSearchService.initializeSearchIndexes();
    
    // Sync with latest data if needed
    await TeamSyncService.syncTeamList();
    
    // Re-initialize search indexes with latest data
    await TeamSearchService.initializeSearchIndexes();
    
    setState(() {
      _searchIndexesReady = true;
      _isLoading = false;
    });
    
    // Perform initial search
    _performSearch(_searchController.text);
  }

  void _onSearchChanged() {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 150), () {
      _performSearch(_searchController.text);
    });
  }

  void _performSearch(String query) {
    if (!_searchIndexesReady) return;
    
    setState(() {
      _isSearching = true;
    });

    // Use optimized search service
    _searchResults = TeamSearchService.searchTeams(query, limit: 200);
    _displayedCount = (_searchResults.length < _loadIncrement) ? _searchResults.length : _loadIncrement;
    
    setState(() {
      _isSearching = false;
    });
  }

  void _loadMoreTeams() {
    setState(() {
      _displayedCount = (_displayedCount + _loadIncrement).clamp(0, _searchResults.length);
    });
  }

  Future<void> _refreshTeamList() async {
    setState(() {
      _isLoading = true;
    });
    
    await TeamSyncService.syncTeamList();
    await TeamSearchService.initializeSearchIndexes();
    
    setState(() {
      _isLoading = false;
    });
    
    _performSearch(_searchController.text);
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
      registered: true, // Assume registered if in master list
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
          hintText: widget.hintText ?? 'Search teams by number, name, or location...',
          hintStyle: AppConstants.bodyText2.copyWith(
            color: AppConstants.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppConstants.textSecondary,
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
                      icon: Icon(Icons.clear, color: AppConstants.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _displayedCount = 0;
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
    if (_isLoading && !_searchIndexesReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_searchIndexesReady) {
      return _buildEmptyState(
        icon: Icons.download,
        title: 'Download Team List',
        message: 'Tap "Update" to download the full VEX IQ team list.',
        actionButton: TextButton(
          onPressed: _isLoading ? null : _refreshTeamList,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update Now'),
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
        title: 'All Teams Loaded',
        message: 'Start typing to search for teams.',
      );
    }

    return ListView.builder(
      itemCount: _displayedCount + (_displayedCount < _searchResults.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedCount) {
          return Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Center(
              child: TextButton(
                onPressed: _loadMoreTeams,
                child: const Text('Load More'),
              ),
            ),
          );
        }
        
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppConstants.vexIQOrange,
                        radius: 24,
                        child: Text(
                          team.number.replaceAll(RegExp(r'[^A-Z]'), ''),
                          style: AppConstants.bodyText1.copyWith(
                            color: Colors.white,
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
                              team.number,
                              style: AppConstants.headline6.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (team.name.isNotEmpty)
                              Text(
                                team.name,
                                style: AppConstants.bodyText1.copyWith(
                                  color: AppConstants.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (team.organization.isNotEmpty)
                              Text(
                                team.organization,
                                style: AppConstants.caption.copyWith(
                                  color: AppConstants.textSecondary,
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
                              color: isFavorite ? Colors.red : AppConstants.textSecondary,
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
                        color: AppConstants.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingM),
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
                              color: AppConstants.textSecondary,
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
              color: AppConstants.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              title,
              style: AppConstants.headline6.copyWith(
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              message,
              style: AppConstants.bodyText2.copyWith(
                color: AppConstants.textSecondary,
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
