import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/robotevents_api.dart';
// import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:stat_iq/utils/date_utils_us.dart';
import 'package:stat_iq/screens/event_details_screen.dart';
import 'package:stat_iq/screens/region_select_screen.dart';
import 'package:stat_iq/screens/season_select_screen.dart';
import 'package:stat_iq/screens/event_level_select_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Event> _events = [];
  List<Event> _currentEvents = [];
  Map<String, List<Event>> _groupedEvents = {};
  Map<String, List<Event>> _groupedCurrentEvents = {};
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  
  // Season selection
  String _selectedSeason = 'Mix & Match (2025-2026)';
  int _selectedSeasonId = 196;
  
  // Filter states
  List<String> _selectedRegions = [];
  String _selectedTimeFrame = 'This Season';
  bool _sortEarliestFirst = true; // Earliest → latest by default
  final Set<String> _collapsedWeeks = {};
  DateTime? _dateRangeStart;
  DateTime? _dateRangeEnd;
  
  // API filter states (Bug Patch 3 requirement) - consolidated into single event level filter
  List<String> _selectedEventLevels = [];
  int _selectedEventsTabIndex = 1;

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

  List<Event> _filterCurrentEvents(List<Event> events) {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 14));
    return events.where((event) {
      final start = event.start;
      final end = event.end;
      if (start == null && end == null) {
        return true; // Unknown schedule, include in current list
      }

      DateTime effectiveStart = start ?? end ?? now;
      DateTime effectiveEnd = end ?? start ?? now;

      // Normalize ordering
      if (effectiveEnd.isBefore(effectiveStart)) {
        effectiveEnd = effectiveStart;
      }

      final overlapsWindow = !effectiveEnd.isBefore(now.subtract(const Duration(days: 1))) &&
          !effectiveStart.isAfter(horizon);
      return overlapsWindow;
    }).toList();
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
      final normalizedSelections = _selectedRegions
          .map((region) => _normalizeRegion(region))
          .where((region) => region.isNotEmpty)
          .toList();
      filteredEvents = filteredEvents.where((event) {
        final eventRegion = _normalizeRegion(_getEventRegion(event));
        final eventCountry = _normalizeRegion(event.country ?? '');
        if (eventRegion.isEmpty && eventCountry.isEmpty) {
          return false;
        }
        return normalizedSelections.any((region) {
          if (eventRegion.isNotEmpty &&
              (eventRegion == region ||
               eventRegion.contains(region) ||
               region.contains(eventRegion))) {
            return true;
          }
          if (eventCountry.isNotEmpty &&
              (eventCountry == region ||
               eventCountry.contains(region) ||
               region.contains(eventCountry))) {
            return true;
          }
          return false;
        });
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

    // Date range filter (optional)
    if (_dateRangeStart != null || _dateRangeEnd != null) {
      final start = _dateRangeStart;
      final end = _dateRangeEnd;
      filteredEvents = filteredEvents.where((e) {
        final d = e.start;
        if (d == null) return false;
        if (start != null && d.isBefore(start)) return false;
        if (end != null && d.isAfter(end)) return false;
        return true;
      }).toList();
    }

    // Event type filtering is now done via API using level_class_id
    // No need for client-side event type filtering

    if (_selectedEventLevels.isNotEmpty) {
      filteredEvents = filteredEvents.where((event) {
        final levelLabel = _getEventLevelLabel(event);
        return _selectedEventLevels.contains(levelLabel);
      }).toList();
    }

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
    
    return '';
  }

  String _normalizeRegion(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _getEventLevelLabel(Event event) {
    if (event.level.isNotEmpty) {
      return ApiConfig.normalizeApiEventLevel(event.level);
    }
    final fallback = _deriveLevelFromMetadata(event);
    return ApiConfig.normalizeApiEventLevel(fallback);
  }

  String _deriveLevelFromMetadata(Event event) {
    final haystack = '${event.name} ${event.levelClassName}'.toLowerCase();
    if (haystack.contains('world')) return 'world';
    if (haystack.contains('signature') || haystack.contains('us open')) return 'signature';
    if (haystack.contains('national')) return 'national';
    if (haystack.contains('regional') || haystack.contains('state') || haystack.contains('provincial')) return 'regional';
    return 'local';
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
        fromDate: _dateRangeStart,
        toDate: _dateRangeEnd,
      );

      // Apply only client-side filters that can't be done via API
      final filteredEvents = _applyClientSideFilters(events);

      final currentEvents = _filterCurrentEvents(filteredEvents);
      final groupedAll = _groupEventsByWeek(filteredEvents);
      final groupedCurrent = _groupEventsByWeek(currentEvents);
      setState(() {
        _events = filteredEvents;
        _currentEvents = currentEvents;
        _groupedEvents = groupedAll;
        _groupedCurrentEvents = groupedCurrent;
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
        _currentEvents = [];
        _groupedCurrentEvents = {};
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
        fromDate: _dateRangeStart,
        toDate: _dateRangeEnd,
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

      final currentEvents = _filterCurrentEvents(filteredEvents);
      final groupedAll = _groupEventsByWeek(filteredEvents);
      final groupedCurrent = _groupEventsByWeek(currentEvents);
      setState(() {
        _events = filteredEvents;
        _currentEvents = currentEvents;
        _groupedEvents = groupedAll;
        _groupedCurrentEvents = groupedCurrent;
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
        _currentEvents = [];
        _groupedCurrentEvents = {};
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
        // Season filter
        Expanded(
          child: _buildFilterButton(
            icon: Icons.event,
            label: _selectedSeason,
            onTap: _showSeasonSelector,
          ),
        ),
        const SizedBox(width: AppConstants.spacingS),
        // Event level filter (Event Level with dropdown arrow)
        Expanded(
          child: _buildFilterButton(
            icon: Icons.category,
            label: _selectedEventLevels.isEmpty 
                ? 'Level' 
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
    final isCurrentTab = _selectedEventsTabIndex == 0;
    final groupedEvents = isCurrentTab ? _groupedCurrentEvents : _groupedEvents;
    final events = isCurrentTab ? _currentEvents : _events;

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
      return Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

    final totalItems = _getTotalItemCount(groupedEvents);
    final hasEvents = totalItems > 0;

    return RefreshIndicator(
      onRefresh: () => _loadRecentEvents(),
      color: AppConstants.vexIQOrange,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
        itemCount: 1 + (hasEvents ? totalItems : 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.spacingS),
                _buildEventsTabSwitcher(),
                const SizedBox(height: AppConstants.spacingS),
                if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                if (_isLoading) const SizedBox(height: AppConstants.spacingS),
              ],
            );
          }
          if (!hasEvents) {
            final message = isCurrentTab
                ? 'No events in the next two weeks.'
                : 'No events found.';
            final subtitle = isCurrentTab && _events.isNotEmpty
                ? 'View the All tab to see upcoming events beyond two weeks.'
                : 'Try a different search term or check back later.';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingXL),
      child: Column(
        children: [
          Icon(
                Icons.event_busy,
            size: 64,
                color: ThemeUtils.getVeryMutedTextColor(context),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
                    message,
                style: AppConstants.headline6.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
                    textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
                    subtitle,
            style: AppConstants.bodyText2.copyWith(
              color: ThemeUtils.getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
            ],
          ),
            );
          }
          final item = _getItemAtIndex(index - 1, groupedEvents);
          if (item is String) {
            return _buildWeekHeader(item, groupedEvents);
          } else {
            final event = item as Event;
            return _buildEventCard(event);
          }
        },
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

  void _showSeasonSelector() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonSelectScreen(
          selectedSeason: _selectedSeason,
          selectedSeasonId: _selectedSeasonId,
        ),
      ),
    );
    if (result != null && mounted) {
      _onSeasonChanged(result['name'] as String, result['id'] as int);
    }
  }
  
  Future<void> _showDateRangePicker() async {
    final initialStart = _dateRangeStart ?? DateTime.now();
    final initialEnd = _dateRangeEnd ?? DateTime.now().add(const Duration(days: 30));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );
    if (picked != null) {
      setState(() {
        _dateRangeStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _dateRangeEnd = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _refreshWithFilters();
    }
  }
  
  void _showRegionFilter() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegionSelectScreen(selectedRegions: _selectedRegions),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedRegions = List<String>.from(result);
      });
      _refreshWithFilters();
    }
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
      _groupedCurrentEvents = _groupEventsByWeek(_currentEvents);
    });
  }
  
  int _getTotalItemCount(Map<String, List<Event>> groupedEvents) {
    int count = 0;
    for (final week in groupedEvents.keys) {
      count += 1; // Week header
      if (!_collapsedWeeks.contains(week)) {
        count += groupedEvents[week]!.length; // Events in week
      }
    }
    return count;
  }
  
  dynamic _getItemAtIndex(int index, Map<String, List<Event>> groupedEvents) {
    int currentIndex = 0;
    final weeks = groupedEvents.keys.toList()..sort();
    final orderedWeeks = _sortEarliestFirst ? weeks : weeks.reversed.toList();
    for (final week in orderedWeeks) {
      if (currentIndex == index) {
        return week; // Week header
      }
      currentIndex++;
      
      if (!_collapsedWeeks.contains(week)) {
        final eventsInWeek = groupedEvents[week]!;
        if (index < currentIndex + eventsInWeek.length) {
          return eventsInWeek[index - currentIndex]; // Event
        }
        currentIndex += eventsInWeek.length;
      }
    }
    return null;
  }
  
  Widget _buildWeekHeader(String weekEnding, Map<String, List<Event>> groupedEvents) {
    final eventCount = groupedEvents[weekEnding]!.length;
    final isCollapsed = _collapsedWeeks.contains(weekEnding);
    return InkWell(
      onTap: () {
        setState(() {
          if (isCollapsed) {
            _collapsedWeeks.remove(weekEnding);
          } else {
            _collapsedWeeks.add(weekEnding);
          }
        });
      },
      child: Container(
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
            const Spacer(),
            Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, color: AppConstants.vexIQBlue),
          ],
        ),
      ),
    );
  }
  
  Color _getEventTypeColorFromLevel(String level) {
    final normalized = ApiConfig.normalizeApiEventLevel(level);
    switch (normalized) {
      case 'World Championship':
        return AppConstants.vexIQRed;
      case 'National Championships':
        return const Color(0xFF9C27B0);
      case 'Regional Championships':
        return AppConstants.vexIQBlue;
      case 'Signature Events':
        return AppConstants.vexIQGreen;
      default:
        return AppConstants.vexIQOrange;
    }
  }

  IconData _getEventTypeIconFromLevel(String level) {
    final normalized = ApiConfig.normalizeApiEventLevel(level);
    switch (normalized) {
      case 'World Championship':
      case 'National Championships':
        return Icons.emoji_events;
      case 'Regional Championships':
      case 'Signature Events':
        return Icons.star;
      default:
        return Icons.event;
    }
  }

  Widget _buildEventCard(Event event) {
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
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                  event.name,
                                  style: AppConstants.bodyText1.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (event.start != null || event.end != null)
                              Text(
                                DateUtilsUS.formatRange(event.start, event.end),
                                style: AppConstants.caption.copyWith(
                                  color: ThemeUtils.getSecondaryTextColor(context),
                                ),
                              ),
                          ],
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                      color: _getEventTypeColorFromLevel(_getEventLevelLabel(event)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                      _getEventLevelLabel(event),
                              style: AppConstants.caption.copyWith(
                        color: _getEventTypeColorFromLevel(_getEventLevelLabel(event)),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                        _getEventTypeIconFromLevel(_getEventLevelLabel(event)),
                                size: 16,
                        color: _getEventTypeColorFromLevel(_getEventLevelLabel(event)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                        _getEventLevelLabel(event),
                                style: AppConstants.caption.copyWith(
                                  color: ThemeUtils.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildEventsTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ThemeUtils.getSecondaryTextColor(context).withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(2, (index) {
            final selected = _selectedEventsTabIndex == index;
            final isCurrent = index == 0;
            final count = isCurrent ? _currentEvents.length : _events.length;
            final borderRadius = index == 0
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  );
            return Expanded(
              child: InkWell(
                borderRadius: borderRadius,
                onTap: () {
                  if (_selectedEventsTabIndex != index) {
                    setState(() {
                      _selectedEventsTabIndex = index;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppConstants.vexIQBlue.withOpacity(0.1) : Colors.transparent,
                    borderRadius: borderRadius,
                  ),
                  child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                      Text(
                        isCurrent ? 'Current' : 'All',
                        style: AppConstants.bodyText2.copyWith(
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                          color: selected ? AppConstants.vexIQBlue : ThemeUtils.getSecondaryTextColor(context),
                        ),
                      ),
                      Text(
                        '$count events',
                        style: AppConstants.caption.copyWith(
                          color: selected
                              ? AppConstants.vexIQBlue
                              : ThemeUtils.getSecondaryTextColor(context).withOpacity(0.7),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
          }),
        ),
      ),
    );
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.schedule),
            onSelected: (value) {
              switch (value) {
                case 'season':
                  _showSeasonSelector();
                  break;
                case 'sort':
                  _showSortOptions();
                  break;
                case 'date':
                  _showDateRangePicker();
                  break;
                case 'refresh':
                  if (!_isLoading) _loadRecentEvents();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'season', child: Text('Select Season')),
              const PopupMenuItem(value: 'sort', child: Text('Sort by Date')),
              const PopupMenuItem(value: 'date', child: Text('Filter by Date Range')),
              const PopupMenuItem(value: 'refresh', child: Text('Refresh Events')),
            ],
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

  void _showEventLevelFilter() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventLevelSelectScreen(selectedLevels: _selectedEventLevels),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedEventLevels = List<String>.from(result);
      });
      _loadRecentEvents();
    }
  }
} 