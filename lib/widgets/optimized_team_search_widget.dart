import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/team_sync_service.dart';
import 'package:stat_iq/services/optimized_team_search.dart';
import 'package:stat_iq/services/special_teams_service.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/screens/team_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'dart:async';

/// Optimized widget for searching 26,000+ teams
/// Uses pagination, lazy loading, and efficient rendering
class OptimizedTeamSearchWidget extends StatefulWidget {
  final String? hintText;
  final bool showSyncStatus;
  final Function(Team)? onTeamSelected;
  final bool isSelectionMode; // New parameter to hide icons in selection mode

  const OptimizedTeamSearchWidget({
    super.key,
    this.hintText,
    this.showSyncStatus = false,
    this.onTeamSelected,
    this.isSelectionMode = false,
  });

  @override
  State<OptimizedTeamSearchWidget> createState() => _OptimizedTeamSearchWidgetState();
}

class _OptimizedTeamSearchWidgetState extends State<OptimizedTeamSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _currentResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _hasData = false;
  int _currentPage = 0;
  bool _hasMoreResults = true;
  String _lastQuery = '';
  Timer? _debouncer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadDataAsync();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _debouncer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDataAsync() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if we need to download data first
      final needsSync = await TeamSyncService.needsSync();
      if (needsSync) {
        print('📥 Team data needs sync, downloading...');
        await TeamSyncService.syncTeamList();
      }
      
      // Initialize optimized search
      await OptimizedTeamSearch.initialize();
      
      if (mounted) {
        final hasData = OptimizedTeamSearch.isReady();
        final teamCount = OptimizedTeamSearch.getTeamCount();
        print('🚀 Optimized search initialized: hasData=$hasData, teamCount=$teamCount');
        print('🚀 Setting _hasData to: $hasData');
        
        setState(() {
          _hasData = hasData;
          _isLoading = false;
        });
        
        print('🚀 After setState: _hasData=$_hasData, _isLoading=$_isLoading');
        
        // Start progress timer if not ready yet
        if (!hasData) {
          _startProgressTimer();
        }
        
        // Show first page of results
        _performSearch('');
      }
    } catch (e) {
      print('❌ Error loading optimized search: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 150), () {
      _performSearch(_searchController.text);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        final isReady = OptimizedTeamSearch.isReady();
        print('🔄 Progress timer: isReady=$isReady, _hasData=$_hasData');
        if (isReady) {
          timer.cancel();
          print('🔄 Setting _hasData to true in progress timer');
          setState(() {
            _hasData = true;
          });
          print('🔄 After setState in timer: _hasData=$_hasData');
        } else {
          setState(() {
            // Trigger rebuild to update progress (both download and indexing)
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _performSearch(String query) {
    print('🔍 _performSearch called with query: "$query"');
    print('🔍 _hasData: $_hasData');
    print('🔍 OptimizedTeamSearch.isReady(): ${OptimizedTeamSearch.isReady()}');
    
    if (!_hasData) {
      print('❌ No data available for search');
      return;
    }
    
    setState(() {
      _isSearching = true;
      _currentPage = 0;
      _hasMoreResults = true;
      _lastQuery = query;
    });

    // Get first page of results
    final results = OptimizedTeamSearch.search(query, page: 0);
    print('🔍 Search results for "$query": ${results.length} teams');
    if (results.isNotEmpty) {
      print('🔍 First result: ${results[0]}');
    } else {
      print('🔍 No results found for query: "$query"');
    }
    
    setState(() {
      _currentResults = results;
      _isSearching = false;
      _hasMoreResults = results.length >= 50; // Assuming page size is 50
    });
    print('🔍 _currentResults length after setState: ${_currentResults.length}');
    print('🔍 _currentResults content: $_currentResults');
    
    print('🔍 Search for "$query": ${results.length} results (page 0)');
  }

  void _loadMoreResults() {
    if (!_hasMoreResults || _isSearching) return;
    
    setState(() {
      _isSearching = true;
      _currentPage++;
    });

    // Get next page
    final moreResults = OptimizedTeamSearch.search(_lastQuery, page: _currentPage);
    
    setState(() {
      _currentResults.addAll(moreResults);
      _isSearching = false;
      _hasMoreResults = moreResults.length >= 50; // Assuming page size is 50
    });
    
    print('📄 Loaded page $_currentPage: ${moreResults.length} more results');
  }

  Future<void> _refreshTeamList() async {
    setState(() {
      _isLoading = true;
    });
    
    await TeamSyncService.syncTeamList();
    await OptimizedTeamSearch.initialize();
    
    if (mounted) {
      setState(() {
        _hasData = OptimizedTeamSearch.isReady();
        _isLoading = false;
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
    print('🔍 OptimizedTeamSearchWidget build() called - _currentResults.length=${_currentResults.length}');
    return SafeArea(
      child: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Sync status (optional)
          if (widget.showSyncStatus) _buildSyncStatus(),

          // Search results
          Flexible(
            child: _buildSearchResults(),
          ),
        ],
      ),
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
          hintText: widget.hintText ?? 'Search 26,000+ teams by number, name, or location...',
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
                        _performSearch('');
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
              Flexible(
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
    print('🔍 _buildSearchResults: _isLoading=$_isLoading, _hasData=$_hasData, _currentResults.length=${_currentResults.length}');
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasData) {
      // Check if we're downloading or indexing
      final downloadProgress = TeamSyncService.getDownloadProgress();
      final downloadStatus = TeamSyncService.getDownloadStatus();
      final indexingProgress = OptimizedTeamSearch.getIndexingProgress();
      final indexingStatus = OptimizedTeamSearch.getIndexingStatus();
      final teamCount = OptimizedTeamSearch.getTeamCount();
      
      // If download is not complete, show download progress
      if (downloadProgress < 1.0) {
        return _buildLoadingState(
          progress: downloadProgress,
          status: downloadStatus,
          teamCount: teamCount,
          isDownloading: true,
        );
      } else {
        // Show indexing progress
        return _buildLoadingState(
          progress: indexingProgress,
          status: indexingStatus,
          teamCount: teamCount,
          isDownloading: false,
        );
      }
    }

    print('🔍 Empty state check: _currentResults.isEmpty=${_currentResults.isEmpty}, _searchController.text.isNotEmpty=${_searchController.text.isNotEmpty}, searchText="${_searchController.text}"');
    
    if (_currentResults.isEmpty && _searchController.text.isNotEmpty) {
      print('🔍 Showing Check Again button for query: "${_searchController.text}"');
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No Teams Found',
        message: 'Try a different team number or check the spelling.',
        actionButton: ElevatedButton.icon(
          onPressed: () {
            print('🔍 Check Again button pressed! Search text: "${_searchController.text}"');
            _performSearch(_searchController.text);
          },
          icon: const Icon(Icons.search),
          label: const Text('Check Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.vexIQBlue,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    if (_currentResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group,
        title: 'No Teams Available',
        message: 'Team database is not loaded yet.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _currentResults.length + (_hasMoreResults ? 1 : 0),
      itemBuilder: (context, index) {
        print('🔍 itemBuilder called: index=$index, _currentResults.length=${_currentResults.length}');
        
        if (index == _currentResults.length) {
          // Load more button
          print('🔍 Building load more button');
          return Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Center(
              child: _isSearching
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: _loadMoreResults,
                      child: const Text('Load More Teams'),
                    ),
            ),
          );
        }

        final teamData = _currentResults[index];
        print('🔍 Building team card for index $index: ${teamData['number']} - ${teamData['name']}');
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

        return Consumer<UserSettings>(
          builder: (context, userSettings, child) {
            final isMyTeam = userSettings.myTeam == team.number;
            final teamTier = SpecialTeamsService.instance.getTeamTier(team.number);
            final tierColorHex = teamTier != null ? SpecialTeamsService.instance.getTierColor(teamTier) : null;
            final tierColor = tierColorHex != null ? Color(int.parse(tierColorHex.replaceAll('#', ''), radix: 16) + 0xFF000000) : null;
            
            return Card(
              margin: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingS,
              ),
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
                onTap: () => _onTeamTap(teamData),
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
                      Flexible(
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
                      if (!widget.isSelectionMode) ...[
                        Consumer<UserSettings>(
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
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  // Team info
                  Row(
                    children: [
                      if (teamTier != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingS,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (tierColor ?? AppConstants.vexIQBlue).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
                            border: Border.all(
                              color: tierColor ?? AppConstants.vexIQBlue,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars,
                                size: 12,
                                color: tierColor ?? AppConstants.vexIQBlue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                SpecialTeamsService.instance.getTierDisplayName(teamTier),
                                style: AppConstants.caption.copyWith(
                                  color: tierColor ?? AppConstants.vexIQBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                      ],
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
                        Flexible(
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

  Widget _buildLoadingState({
    required double progress,
    required String status,
    required int teamCount,
    bool isDownloading = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDownloading ? Icons.download : Icons.build,
              size: 64,
              color: AppConstants.vexIQBlue.withOpacity(0.7),
            ),
            const SizedBox(height: AppConstants.spacingM),
            Text(
              isDownloading ? 'Downloading Team Database' : 'Building Search Index',
              style: AppConstants.headline6.copyWith(
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              status,
              style: AppConstants.bodyText2.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingM),
            // Progress bar
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: AppConstants.surfaceColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppConstants.borderColor),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppConstants.vexIQBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppConstants.caption.copyWith(
                color: AppConstants.vexIQBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              '$teamCount teams loaded',
              style: AppConstants.caption.copyWith(
                color: ThemeUtils.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}