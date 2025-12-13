import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/team_sync_service.dart';
import 'package:stat_iq/services/team_search_service.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:stat_iq/models/team.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/utils/logger.dart';
import 'dart:async';

class TeamSearchWidget extends StatefulWidget {
  final Function(Team)? onTeamSelected;
  final String? hintText;
  final bool showSyncStatus;

  const TeamSearchWidget({
    super.key,
    this.onTeamSelected,
    this.hintText,
    this.showSyncStatus = true,
  });

  @override
  State<TeamSearchWidget> createState() => _TeamSearchWidgetState();
}

class _TeamSearchWidgetState extends State<TeamSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String _lastQuery = '';
  int _displayedCount = 0;
  static const int _batchSize = 50; // Load 50 results at a time

  @override
  void initState() {
    super.initState();
    _checkAndSyncTeamList();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _lastQuery) {
      _lastQuery = query;
      _debounceSearch();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  void _debounceSearch() {
    // Cancel previous timer if exists
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim() == _lastQuery) {
        _performSearch(_lastQuery);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _displayedCount = 0;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await TeamSyncService.searchTeams(query);
      setState(() {
        _searchResults = results;
        _displayedCount = results.length > _batchSize ? _batchSize : results.length;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      AppLogger.d('Search error: $e');
    }
  }

  void _loadMoreResults() {
    if (_displayedCount < _searchResults.length) {
      setState(() {
        _displayedCount = (_displayedCount + _batchSize).clamp(0, _searchResults.length);
      });
    }
  }

  Future<void> _checkAndSyncTeamList() async {
    final needsSync = await TeamSyncService.needsSync();
    if (needsSync) {
      setState(() {
        _isLoading = true;
      });
      
      final success = await TeamSyncService.syncTeamList();
      setState(() {
        _isLoading = false;
      });
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync team list. Using cached data.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _refreshTeamList() async {
    setState(() {
      _isLoading = true;
    });
    
    final success = await TeamSyncService.forceSync();
    setState(() {
      _isLoading = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Team list updated successfully!' 
              : 'Failed to update team list'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _onTeamTap(Map<String, dynamic> teamData) {
    final team = Team(
      id: teamData['id'] ?? 0,
      number: teamData['number'] ?? '',
      name: teamData['name'] ?? '',
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
        // final lastSync = status['lastSync'] as DateTime?;
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
    if (_searchController.text.trim().isEmpty) {
      return _buildEmptyState();
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildNoResults();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppConstants.spacingM),
      itemCount: _displayedCount + (_displayedCount < _searchResults.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedCount) {
          return _buildLoadMoreButton();
        }
        
        final team = _searchResults[index];
        return _buildTeamCard(team);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: ThemeUtils.getVeryMutedTextColor(context),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            'Search Teams',
            style: AppConstants.headline6.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Enter a team number, name, or location to search',
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
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
            'Try searching with a different term',
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      elevation: AppConstants.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
      ),
      child: ListTile(
        onTap: () => _onTeamTap(team),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppConstants.vexIQBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
          ),
          child: Center(
            child: Text(
              team['number'] ?? '?',
              style: AppConstants.bodyText1.copyWith(
                fontWeight: FontWeight.bold,
                color: AppConstants.vexIQBlue,
              ),
            ),
          ),
        ),
        title: Text(
          team['name'] ?? 'Unknown Team',
          style: AppConstants.bodyText1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team['organization']?.isNotEmpty == true)
              Text(
                team['organization'],
                style: AppConstants.bodyText2,
              ),
            if (team['location']?.isNotEmpty == true)
              Text(
                team['location'],
                style: AppConstants.caption.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
                  color: ThemeUtils.getSecondaryTextColor(context),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Center(
        child: TextButton(
          onPressed: _loadMoreResults,
          child: Text(
            'Load More (${_searchResults.length - _displayedCount} remaining)',
            style: AppConstants.bodyText2.copyWith(
              color: AppConstants.vexIQBlue,
            ),
          ),
        ),
      ),
    );
  }
}
