import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/robotevents_api.dart';
// import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/screens/event_details_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Event> _events = [];
  Map<String, List<Event>> _groupedEvents = {};
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  
  // Season selection
  String _selectedSeason = 'Mix & Match (2025-2026)';
  int _selectedSeasonId = 196;
  
  // Filter states
  List<String> _selectedRegions = [];
  String _selectedTimeFrame = 'This Season';
  bool _sortEarliestFirst = true;
  
  // API filter states (Bug Patch 3 requirement) - consolidated into single event level filter
  List<String> _selectedEventLevels = [];

  @override
  void initState() {
    super.initState();
    _loadRecentEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _onSeasonChanged(String seasonName, int seasonId) {
    setState(() {
      _selectedSeason = seasonName;
      _selectedSeasonId = seasonId;
    });
    
    // Reload events with new season
    if (_hasSearched) {
      if (_searchController.text.trim().isNotEmpty) {
        _searchEvents(_searchController.text);
      } else {
        _loadRecentEvents();
      }
    }
  }

  Map<String, List<Event>> _groupEventsByWeek(List<Event> events) {
    final Map<String, List<Event>> weekGroups = {};
    
    for (final event in events) {
      if (event.start != null) {
        final weekEnding = _getWeekEnding(event.start!);
        weekGroups.putIfAbsent(weekEnding, () => []).add(event);
      }
    }
    
    // Sort events within each week
    for (final week in weekGroups.keys) {
      weekGroups[week]!.sort((a, b) {
        if (a.start == null && b.start == null) return 0;
        if (a.start == null) return 1;
        if (b.start == null) return -1;
        
        if (_sortEarliestFirst) {
          return a.start!.compareTo(b.start!);
        } else {
          return b.start!.compareTo(a.start!);
        }
      });
    }
    
    return weekGroups;
  }
  
  String _getWeekEnding(DateTime date) {
    // Calculate the Sunday that ends the week
    final daysUntilSunday = 7 - date.weekday;
    final weekEnding = date.add(Duration(days: daysUntilSunday));
    
    // Format as "Week ending M/d"
    final month = weekEnding.month;
    final day = weekEnding.day;
    return 'Week ending $month/$day';
  }

  List<Event> _applyClientSideFilters(List<Event> events) {
    List<Event> filteredEvents = List.from(events);

    // Apply region filter (can't be done via API)
    if (_selectedRegions.isNotEmpty) {
      filteredEvents = filteredEvents.where((event) {
        final eventRegion = _getEventRegion(event);
        return _selectedRegions.contains(eventRegion);
      }).toList();
    }

    // Apply time frame filter (can't be done via API)
      final now = DateTime.now();
      filteredEvents = filteredEvents.where((event) {
        final eventDate = event.start;
        if (eventDate == null) return false;

        switch (_selectedTimeFrame) {
          case 'This Week':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 7));
            return eventDate.isAfter(weekStart) && eventDate.isBefore(weekEnd);
          case 'This Month':
            final monthStart = DateTime(now.year, now.month, 1);
            final monthEnd = DateTime(now.year, now.month + 1, 1);
            return eventDate.isAfter(monthStart) && eventDate.isBefore(monthEnd);
          case 'Next Month':
            final nextMonthStart = DateTime(now.year, now.month + 1, 1);
            final nextMonthEnd = DateTime(now.year, now.month + 2, 1);
            return eventDate.isAfter(nextMonthStart) && eventDate.isBefore(nextMonthEnd);
          case 'This Season':
            // For VEX IQ, season typically runs from August to May
          // But when a different season is selected, show all events from that season
          if (_selectedSeasonId != 196) { // Not current season
            return true; // Show all events for past seasons
          }
            final seasonStart = DateTime(now.year, 8, 1);
            final seasonEnd = DateTime(now.year + 1, 6, 1);
            return eventDate.isAfter(seasonStart) && eventDate.isBefore(seasonEnd);
          default:
            return true;
        }
      }).toList();

    // Event type filtering is now done via API using level_class_id
    // No need for client-side event type filtering

    return filteredEvents;
  }

  String _getEventRegion(Event event) {
    final country = event.country ?? '';
    final region = event.region ?? '';
    
    // Return the most specific region available
    if (region.isNotEmpty) {
      return region;
    }
    
    // If no specific region, return country
    if (country.isNotEmpty) {
      return country;
    }
    
    return 'Unknown';
  }

  String _getEventType(Event event) {
    final name = event.name?.toLowerCase() ?? '';
    final levelClass = event.levelClassName?.toLowerCase() ?? '';
    
    if (name.contains('world') || name.contains('championship') || 
        name.contains('us open') || name.contains('vex worlds')) {
      return 'Important (US Open, Worlds)';
    } else if (name.contains('regional') || name.contains('state') || 
               name.contains('provincial') || name.contains('national')) {
      return 'Regional/States';
    } else if (name.contains('school') || name.contains('district') ||
               levelClass.contains('school')) {
      return 'School-Only';
    } else if (name.contains('signature') || name.contains('expo') ||
               name.contains('showcase')) {
      return 'Signature';
    } else {
      return 'Local';
    }
  }

  Future<void> _loadRecentEvents() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
    });

    try {
      // Load events from selected season with API filters
      final events = await RobotEventsAPI.searchEvents(
        seasonId: _selectedSeasonId,
        levels: _selectedEventLevels.isNotEmpty ? _selectedEventLevels : null,
        page: 1,
      );

      // Apply only client-side filters that can't be done via API
      final filteredEvents = _applyClientSideFilters(events);

      setState(() {
        _events = filteredEvents;
        _groupedEvents = _groupEventsByWeek(filteredEvents);
        _isLoading = false;
        if (filteredEvents.isEmpty) {
          _errorMessage = 'No events found matching your filters for $_selectedSeason';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading events: ${e.toString()}';
        _events = [];
        _groupedEvents = {};
      });
    }
  }

  Future<void> _searchEvents(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
    });

    try {
      // Check if query contains season information - if so, don't pass explicit seasonId
      // to allow auto-detection to work
      final queryLower = query.toLowerCase();
      final hasSeasonInfo = queryLower.contains('2024-2025') || 
                           queryLower.contains('2024-25') || 
                           queryLower.contains('2023-2024') || 
                           queryLower.contains('2023-24') || 
                           queryLower.contains('2025-2026') || 
                           queryLower.contains('2025-26') ||
                           queryLower.contains('rapid relay') ||
                           queryLower.contains('full volume') ||
                           queryLower.contains('mix & match');
      
      print('🔍 Events Screen: Query contains season info: $hasSeasonInfo');
      print('🔍 Events Screen: Selected season ID: $_selectedSeasonId');
      print('🔍 Events Screen: Query: "$query" (length: ${query.trim().length})');
      print('🔍 Events Screen: Will pass seasonId: ${hasSeasonInfo ? null : _selectedSeasonId}');
      print('🔍 Events Screen: Making API call to confirm results...');
      
      // Always make API call for non-empty queries to confirm results
      final events = await RobotEventsAPI.searchEvents(
        query: query.trim().isEmpty ? null : query.trim(),
        seasonId: hasSeasonInfo ? null : _selectedSeasonId, // Let auto-detection work if query has season
        levels: _selectedEventLevels.isNotEmpty ? _selectedEventLevels : null,
      );
      
      print('🔍 Events Screen: Found ${events.length} events');
      if (events.isNotEmpty) {
        print('🔍 Events Screen: First event: ${events.first.name}');
      }

      // Apply only client-side filters that can't be done via API
      final filteredEvents = _applyClientSideFilters(events);

      // If no events found, try additional searches to confirm no results exist
      if (filteredEvents.isEmpty && query.trim().isNotEmpty) {
        print('🔍 No events found, trying additional search confirmations...');
        
        // Try team search fallback
        try {
          print('🔍 Trying exact team search for: "${query.trim()}"');
          final teams = await RobotEventsAPI.searchTeams(teamNumber: query.trim());
          print('🔍 Exact team search found ${teams.length} teams');
          
          if (teams.isNotEmpty) {
            // If teams are found, show a message suggesting to search for teams instead
            setState(() {
              _events = [];
              _groupedEvents = {};
              _isLoading = false;
              _errorMessage = 'No events found for "$query", but ${teams.length} team(s) were found. Try searching for teams instead.';
            });
            return;
          }
          
          // Try searching without season filter for teams
          if (query.trim().length > 1) {
            print('🔍 Trying team search without season filter for: "${query.trim()}"');
            final teamsNoSeason = await RobotEventsAPI.searchTeams(teamNumber: query.trim(), seasonId: null);
            print('🔍 Team search without season found ${teamsNoSeason.length} teams');
            
            if (teamsNoSeason.isNotEmpty) {
              setState(() {
                _events = [];
                _groupedEvents = {};
                _isLoading = false;
                _errorMessage = 'No events found for "$query", but ${teamsNoSeason.length} team(s) were found (including other seasons). Try searching for teams instead.';
              });
              return;
            }
          }
        } catch (e) {
          print('🔍 Team search fallback failed: $e');
        }
        
        // Try a broader event search without filters to confirm no results exist
        try {
          print('🔍 Trying broader event search without filters...');
          final broaderEvents = await RobotEventsAPI.searchEvents(
            query: query.trim(),
            seasonId: null, // Try without season filter
            levels: _selectedEventLevels.isNotEmpty ? _selectedEventLevels : null,
          );
          print('🔍 Broader search found ${broaderEvents.length} events');
          
          if (broaderEvents.isNotEmpty) {
            // If broader search found events, it means filters are too restrictive
            setState(() {
              _events = [];
              _groupedEvents = {};
              _isLoading = false;
              _errorMessage = 'No events found for "$query" with current filters. Try adjusting your filters or search terms.';
            });
            return;
          }
        } catch (e) {
          print('🔍 Broader search failed: $e');
        }
      }

      setState(() {
        _events = filteredEvents;
        _groupedEvents = _groupEventsByWeek(filteredEvents);
        _isLoading = false;
        if (filteredEvents.isEmpty) {
          final searchTerm = query.trim().isEmpty ? 'recent events' : '"$query"';
          _errorMessage = 'No events found for $searchTerm matching your filters in $_selectedSeason. API search confirmed no results.';
          } else {
            _errorMessage = ''; // Clear error message when events are found
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error searching events: ${e.toString()}';
        _events = [];
        _groupedEvents = {};
      });
    }
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: AppConstants.spacingM),
          _buildFilterButtons(),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search by name & location',
        prefixIcon: Icon(
          Icons.search,
          color: _searchController.text.isEmpty 
              ? ThemeUtils.getSecondaryTextColor(context) 
              : AppConstants.vexIQOrange,
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _loadRecentEvents();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          borderSide: const BorderSide(color: AppConstants.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
          borderSide: BorderSide(color: AppConstants.vexIQOrange, width: 2),
        ),
      ),
      onChanged: (value) {
        setState(() {}); // Update UI for clear button
        if (value.trim().isNotEmpty) {
          _searchEvents(value);
        } else {
          _loadRecentEvents();
        }
      },
      onSubmitted: _searchEvents,
    );
  }
  
  Widget _buildFilterButtons() {
    return Row(
      children: [
        // Region filter (Globe icon)
        Expanded(
          child: _buildFilterButton(
            icon: Icons.public,
            label: _selectedRegions.isEmpty ? 'Region' : '${_selectedRegions.length} selected',
            onTap: _showRegionFilter,
          ),
        ),
        const SizedBox(width: AppConstants.spacingS),
        // Time frame filter (Calendar icon)
        Expanded(
          child: _buildFilterButton(
            icon: Icons.calendar_today,
            label: _selectedTimeFrame,
            onTap: _showTimeFrameFilter,
          ),
        ),
        const SizedBox(width: AppConstants.spacingS),
        // Event level filter (Event Level with dropdown arrow)
        Expanded(
          child: _buildFilterButton(
            icon: Icons.category,
            label: _selectedEventLevels.isEmpty 
                ? 'Filter by event level ▼' 
                : '${_selectedEventLevels.length} Level${_selectedEventLevels.length == 1 ? '' : 's'} ▼',
            onTap: _showEventLevelFilter,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingS,
          vertical: AppConstants.spacingS,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppConstants.borderColor),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppConstants.vexIQOrange,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: AppConstants.caption.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }
  

  Widget _buildApiStatusBanner() {
    if (!ApiConfig.isApiKeyConfigured) {
      return Container(
        width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
        margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
            decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          border: Border.all(color: Colors.orange),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
            ),
            child: Row(
              children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade700,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                    'API Key Required',
                    style: AppConstants.bodyText1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                    'Set your RobotEvents API key to view live event data',
                    style: AppConstants.bodyText2.copyWith(
                      color: Colors.orange.shade600,
                    ),
                  ),
              ],
            ),
          ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEventsList() {
    if (_errorMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade400,
                  size: 48,
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Error',
                  style: AppConstants.headline6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                    Text(
                  _errorMessage,
                      style: AppConstants.bodyText2.copyWith(
                        color: ThemeUtils.getSecondaryTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                ElevatedButton.icon(
                  onPressed: () => _loadRecentEvents(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.vexIQOrange,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    if (_hasSearched) ...[
                      const SizedBox(width: AppConstants.spacingS),
                      ElevatedButton.icon(
                        onPressed: () {
                          print('🔍 Events Check Again button pressed! Search text: "${_searchController.text}"');
                          // If search text is empty, reload recent events, otherwise search again
                          if (_searchController.text.trim().isEmpty) {
                            print('🔍 Loading recent events...');
                            _loadRecentEvents();
                          } else {
                            print('🔍 Searching events again...');
                            _searchEvents(_searchController.text);
                          }
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Check Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.vexIQBlue,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ),
    );
  }

    if (!_hasSearched || (_isLoading && _events.isEmpty)) {
      return Expanded(
        child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
              // Enhanced loading indicator with animation
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      color: AppConstants.vexIQOrange,
                      strokeWidth: 6,
                    ),
                  ),
                  Icon(
                    Icons.search,
                color: AppConstants.vexIQOrange,
                    size: 32,
                  ),
                ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
                'Comprehensive Search in Progress',
                style: AppConstants.headline6.copyWith(
              color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.bold,
            ),
          ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Searching through all events...',
                style: AppConstants.bodyText1.copyWith(
                  color: ThemeUtils.getSecondaryTextColor(context),
            ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingS),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.vexIQOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                  border: Border.all(color: AppConstants.vexIQOrange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppConstants.vexIQOrange,
                      size: 16,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(
                      'Please wait, this may take a few moments',
                      style: AppConstants.caption.copyWith(
                        color: AppConstants.vexIQOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingL),
              // Progress dots animation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 600 + (index * 200)),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: AppConstants.vexIQOrange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
          ),
        ],
          ),
      ),
    );
  }

    if (_events.isEmpty && !_isLoading) {
      return Expanded(
        child: Center(
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
                'No Events Found',
                style: AppConstants.headline6.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
                'Try a different search term or check back later',
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: () => _loadRecentEvents(),
        color: AppConstants.vexIQOrange,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          itemCount: _getTotalItemCount(),
          itemBuilder: (context, index) {
            final item = _getItemAtIndex(index);
            if (item is String) {
              // This is a week header
              return _buildWeekHeader(item);
            } else {
              // This is an event
              final event = item as Event;
            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event name and location spanning full width
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.name,
                                  style: AppConstants.bodyText1.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_getEventLocation(event).isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _getEventLocation(event),
                                    style: AppConstants.caption.copyWith(
                                      color: ThemeUtils.getSecondaryTextColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Event type badge (MS, ES, or Blended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getEventTypeColor(event.name).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getEventTypeLabel(event.name),
                              style: AppConstants.caption.copyWith(
                                color: _getEventTypeColor(event.name),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      // Bottom row with favorite button and arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Event type icon
                          Row(
                            children: [
                              Icon(
                                _getEventTypeIcon(event.name),
                                size: 16,
                                color: _getEventTypeColor(event.name),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getEventTypeName(event.name),
                                style: AppConstants.caption.copyWith(
                                  color: ThemeUtils.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                          // Favorite button and arrow
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Consumer<UserSettings>(
                                builder: (context, settings, child) {
                                  final isFavorite = settings.isFavoriteEvent(event.sku);
                                  return IconButton(
                                    icon: Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? Colors.red : Theme.of(context).iconTheme.color,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      if (isFavorite) {
                                        await settings.removeFavoriteEvent(event.sku);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${event.name} removed from favorites')),
                                          );
                                        }
                                      } else {
                                        await settings.addFavoriteEvent(event.sku);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('${event.name} added to favorites')),
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
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            }
          },
        ),
      ),
    );
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Events'),
        content: Column(
              mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<bool>(
              title: Row(
                children: [
                  Icon(Icons.keyboard_arrow_up, color: AppConstants.vexIQOrange),
                  const SizedBox(width: 8),
                  const Text('Earliest First'),
                ],
              ),
              value: true,
              groupValue: _sortEarliestFirst,
                  onChanged: (value) {
                    setState(() {
                  _sortEarliestFirst = value!;
                });
                _refreshGrouping();
                Navigator.pop(context);
              },
            ),
            RadioListTile<bool>(
              title: Row(
                children: [
                  Icon(Icons.keyboard_arrow_down, color: AppConstants.vexIQOrange),
                  const SizedBox(width: 8),
                  const Text('Latest First'),
                ],
              ),
              value: false,
              groupValue: _sortEarliestFirst,
              onChanged: (value) {
                setState(() {
                  _sortEarliestFirst = value!;
                });
                _refreshGrouping();
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSeasonSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Season'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ApiConfig.availableSeasons.keys.map((String seasonName) {
            return RadioListTile<String>(
              title: Text(seasonName),
              value: seasonName,
              groupValue: _selectedSeason,
              onChanged: (value) {
                if (value != null) {
                  final seasonId = ApiConfig.availableSeasons[value]!['vexiq']!;
                  _onSeasonChanged(value, seasonId);
                }
              Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showRegionFilter() {
    final allVexIQRegions = [
      // North America - US States
      'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California - North', 'California - South',
      'Colorado', 'Connecticut', 'Delaware', 'Florida - North/Central', 'Florida - South',
      'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana - Region 1 - North',
      'Indiana - Region 2 - Central', 'Indiana - Region 3 - South', 'Iowa', 'Kansas',
      'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan',
      'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada',
      'New Hampshire', 'New Jersey', 'New Mexico', 'New York', 'North Carolina',
      'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island',
      'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
      'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming',
      'District of Columbia', 'Delmarva',
      
      // Canada
      'Alberta/Saskatchewan', 'British Columbia', 'British Columbia (BC)', 'Manitoba',
      'New Brunswick', 'Newfoundland and Labrador', 'Northwest Territories',
      'Nova Scotia', 'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
      'Saskatchewan', 'Yukon',
      
      // Mexico
      'Mexico',
      
      // Europe
      'Austria', 'Belgium', 'Bulgaria', 'Croatia', 'Czech Republic', 'Denmark',
      'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Hungary', 'Iceland',
      'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Netherlands', 'Norway',
      'Poland', 'Portugal', 'Romania', 'Slovakia', 'Slovenia', 'Spain',
      'Sweden', 'Switzerland', 'United Kingdom',
      
      // Asia
      'China', 'East China', 'West China', 'North China', 'Middle China',
      'Hong Kong', 'India', 'Indonesia', 'Japan', 'Kazakhstan', 'Kuwait',
      'Malaysia', 'Philippines', 'Singapore', 'South Korea', 'Thailand',
      'United Arab Emirates', 'Vietnam', 'Chinese Taipei',
      
      // South America
      'Argentina', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Ecuador',
      'Paraguay', 'Peru', 'Uruguay', 'Venezuela',
      
      // Middle East & Africa
      'Bahrain', 'Egypt', 'Israel', 'Jordan', 'Lebanon', 'Morocco',
      'Qatar', 'Saudi Arabia', 'South Africa', 'Turkey',
      
      // Oceania
      'Australia', 'New Zealand', 'Fiji', 'Papua New Guinea',
      
      // Other
      'Afghanistan', 'Albania', 'Algeria', 'American Samoa', 'Andorra',
      'Angola', 'Antigua and Barbuda', 'Armenia', 'Aruba', 'Azerbaijan',
      'Bahamas', 'Bangladesh', 'Barbados', 'Belarus', 'Belize', 'Benin',
      'Bermuda', 'Bhutan', 'Bosnia and Herzegovina', 'Botswana', 'Brunei',
      'Burkina Faso', 'Burundi', 'Cambodia', 'Cameroon', 'Canada',
      'Cape Verde', 'Cayman Islands', 'Central African Republic', 'Chad',
      'Comoros', 'Congo', 'Cook Islands', 'Costa Rica', 'Cuba', 'Cyprus',
      'Democratic Republic of the Congo', 'Djibouti', 'Dominican Republic',
      'East Timor', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Eswatini',
      'Ethiopia', 'Falkland Islands', 'French Guiana', 'French Polynesia',
      'French Southern and Antarctic Territories', 'Gabon', 'Gambia',
      'Georgia- Country', 'Ghana', 'Greenland', 'Guam', 'Guatemala',
      'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras', 'Iraq',
      'Jamaica', 'Kenya', 'Kiribati', 'Kosovo', 'Kyrgyzstan', 'Laos',
      'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Luxembourg',
      'Macedonia', 'Madagascar', 'Malawi', 'Maldives', 'Mali', 'Malta',
      'Marshall Islands', 'Mauritania', 'Mauritius', 'Micronesia',
      'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Mozambique', 'Myanmar',
      'Namibia', 'Nauru', 'Nepal', 'Nicaragua', 'Niger', 'Nigeria',
      'Niue', 'North Korea', 'Northern Mariana Islands', 'Oman', 'Palau',
      'Panama', 'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia',
      'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
      'Sao Tome and Principe', 'Senegal', 'Serbia', 'Seychelles',
      'Sierra Leone', 'Solomon Islands', 'Somalia', 'South Sudan',
      'Sri Lanka', 'Sudan', 'Suriname', 'Swaziland', 'Syria', 'Tajikistan',
      'Tanzania', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia',
      'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine', 'Uzbekistan',
      'Vanuatu', 'Vatican City', 'Yemen', 'Zambia', 'Zimbabwe'
    ];
    
    final TextEditingController searchController = TextEditingController();
    List<String> filteredRegions = List.from(allVexIQRegions);
    
    showDialog(
      context: context,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final availableHeight = mediaQuery.size.height - keyboardHeight;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select VEX IQ Regions'),
              content: SizedBox(
                width: double.maxFinite,
                height: (availableHeight * 0.7).clamp(400.0, 600.0),
              child: Column(
          children: [
                  // Search bar
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search regions...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                onChanged: (value) {
                  setState(() {
                        filteredRegions = allVexIQRegions
                            .where((region) => region.toLowerCase().contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  // Clear all / Select all buttons
            Row(
              children: [
                Expanded(
                        child: TextButton(
                          onPressed: () {
                          setState(() {
                              _selectedRegions.clear();
                          });
                        },
                          child: const Text('Clear All'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                          setState(() {
                              _selectedRegions = List.from(filteredRegions);
                          });
                        },
                          child: const Text('Select All'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Region list
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredRegions.length,
                      itemBuilder: (context, index) {
                        final region = filteredRegions[index];
                final isSelected = _selectedRegions.contains(region);
                return CheckboxListTile(
                          title: Text(
                            region,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedRegions.add(region);
                      } else {
                        _selectedRegions.remove(region);
                      }
                    });
                  },
            );
          },
                    ),
                  ),
                ],
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              _refreshWithFilters();
            },
            child: const Text('Apply'),
          ),
        ],
            );
          },
        );
      },
    );
  }
  
  void _showTimeFrameFilter() {
    final timeFrames = [
      'This Week',
      'This Month',
      'Next Month',
      'This Season',
    ];
    
    showDialog(
      context: context,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final availableHeight = mediaQuery.size.height - keyboardHeight;
        
        return AlertDialog(
          title: const Text('Select Time Frame'),
          content: SizedBox(
            width: double.maxFinite,
            height: (availableHeight * 0.4).clamp(200.0, 400.0),
          child: Column(
          children: [
            ...timeFrames.map((timeFrame) {
            return RadioListTile<String>(
                  title: Text(
                    timeFrame,
                    style: const TextStyle(fontSize: 16),
                  ),
                value: timeFrame,
                groupValue: _selectedTimeFrame,
              onChanged: (value) {
                setState(() {
                    _selectedTimeFrame = value!;
                });
                Navigator.pop(context);
                _refreshWithFilters();
              },
            );
            }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
        );
      },
    );
  }
  
  
  void _refreshWithFilters() {
    // Refresh events with current filters applied
    if (_searchController.text.trim().isNotEmpty) {
      _searchEvents(_searchController.text);
    } else {
      _loadRecentEvents();
    }
  }
  
  void _refreshGrouping() {
    // Refresh grouping when sort order changes
    setState(() {
      _groupedEvents = _groupEventsByWeek(_events);
    });
  }
  
  int _getTotalItemCount() {
    int count = 0;
    for (final week in _groupedEvents.keys) {
      count += 1; // Week header
      count += _groupedEvents[week]!.length; // Events in week
    }
    return count;
  }
  
  dynamic _getItemAtIndex(int index) {
    int currentIndex = 0;
    for (final week in _groupedEvents.keys.toList()..sort()) {
      if (currentIndex == index) {
        return week; // Week header
      }
      currentIndex++;
      
      final eventsInWeek = _groupedEvents[week]!;
      if (index < currentIndex + eventsInWeek.length) {
        return eventsInWeek[index - currentIndex]; // Event
      }
      currentIndex += eventsInWeek.length;
    }
    return null;
  }
  
  Widget _buildWeekHeader(String weekEnding) {
    final eventCount = _groupedEvents[weekEnding]!.length;
    return Container(
      margin: const EdgeInsets.only(top: AppConstants.spacingM, bottom: AppConstants.spacingS),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingM,
        vertical: AppConstants.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppConstants.vexIQBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        border: Border.all(color: AppConstants.vexIQBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_view_week,
            color: AppConstants.vexIQBlue,
            size: 20,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Text(
            '$weekEnding ($eventCount ${eventCount == 1 ? 'event' : 'events'})',
            style: AppConstants.bodyText1.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.vexIQBlue,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventTypeColor(String eventName) {
    final name = eventName.toLowerCase();
    if (name.contains('championship') || name.contains('worlds')) {
      return AppConstants.vexIQRed;
    } else if (name.contains('signature') || name.contains('regional')) {
      return AppConstants.vexIQBlue;
    } else {
        return AppConstants.vexIQOrange;
    }
  }

  IconData _getEventTypeIcon(String eventName) {
    final name = eventName.toLowerCase();
    if (name.contains('championship') || name.contains('worlds')) {
        return Icons.emoji_events;
    } else if (name.contains('signature') || name.contains('regional')) {
      return Icons.star;
    } else {
        return Icons.event;
    }
  }
  
  String _getEventTypeLabel(String eventName) {
    final name = eventName.toLowerCase();
    if (name.contains('middle school') || name.contains('ms')) {
      return 'MS';
    } else if (name.contains('elementary') || name.contains('es')) {
      return 'ES';
    } else {
      return 'Blended';
    }
  }
  
  String _getEventTypeName(String eventName) {
    final name = eventName.toLowerCase();
    if (name.contains('championship') || name.contains('worlds')) {
      return 'Championship';
    } else if (name.contains('signature')) {
      return 'Signature';
    } else if (name.contains('regional') || name.contains('state')) {
      return 'Regional';
    } else if (name.contains('school')) {
      return 'School-Only';
    } else {
      return 'Local';
    }
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

  String _formatEventDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 0 && difference <= 7) {
      return 'In $difference days';
    } else if (difference < 0 && difference >= -7) {
      return '${-difference} days ago';
    } else {
      // Format as MM/DD/YYYY
      return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events',
          style: AppConstants.headline5.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: _showSeasonSelector,
            tooltip: 'Select Season',
          ),
          IconButton(
            icon: const Icon(Icons.access_time),
            onPressed: _showSortOptions,
            tooltip: 'Sort by Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _loadRecentEvents(),
            tooltip: 'Refresh Events',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          _buildApiStatusBanner(),
          Expanded(child: _buildEventsList()),
        ],
      ),
    );
  }

  void _showEventLevelFilter() {
    showDialog(
      context: context,
      builder: (context) {
        final mediaQuery = MediaQuery.of(context);
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final availableHeight = mediaQuery.size.height - keyboardHeight;
        
        return AlertDialog(
          title: const Text('Filter by Event Level'),
          content: SizedBox(
            width: double.maxFinite,
            height: (availableHeight * 0.8).clamp(400.0, 700.0), // Increased height for better usability
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _selectedEventLevels = List.from(ApiConfig.availableEventLevels);
                          });
                        },
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _selectedEventLevels.clear();
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: ApiConfig.availableEventLevels.length,
                      itemBuilder: (context, index) {
                        final level = ApiConfig.availableEventLevels[index];
                        final isSelected = _selectedEventLevels.contains(level);
                        
                        // Display name mapping for UI
                        String displayName = level;
                        if (level == 'State') {
                          displayName = 'Regional Championships';
                        } else if (level == 'National') {
                          displayName = 'National Championships';
                        } else if (level == 'Signature') {
                          displayName = 'Signature Events';
                        } else if (level == 'World') {
                          displayName = 'Worlds';
                        } else if (level == 'Other') {
                          displayName = 'All';
                        }
                        
                        return CheckboxListTile(
                          title: Text(displayName),
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                _selectedEventLevels.add(level);
                              } else {
                                _selectedEventLevels.remove(level);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRecentEvents(); // Reload events with new filter
            },
            child: const Text('Apply'),
          ),
        ],
        );
      },
    );
  }
} 