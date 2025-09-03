import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/models/event.dart';
import 'package:stat_iq/constants/api_config.dart';
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
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  
  // Season selection
  String _selectedSeason = 'Mix & Match (2025-2026)';
  int _selectedSeasonId = 196;

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

  Future<void> _loadRecentEvents() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
    });

    try {
      // Load events from selected season
      final events = await RobotEventsAPI.searchEvents(
        seasonId: _selectedSeasonId,
        page: 1,
      );

      setState(() {
        _events = events;
        _isLoading = false;
        if (events.isEmpty) {
          _errorMessage = 'No recent events found for $_selectedSeason';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading events: ${e.toString()}';
        _events = [];
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
      print('🔍 Events Screen: Query: "$query"');
      print('🔍 Events Screen: Will pass seasonId: ${hasSeasonInfo ? null : _selectedSeasonId}');
      
      final events = await RobotEventsAPI.searchEvents(
        query: query.trim().isEmpty ? null : query.trim(),
        seasonId: hasSeasonInfo ? null : _selectedSeasonId, // Let auto-detection work if query has season
      );
      
      print('🔍 Events Screen: Found ${events.length} events');
      if (events.isNotEmpty) {
        print('🔍 Events Screen: First event: ${events.first.name}');
      }

      setState(() {
        _events = events;
        _isLoading = false;
        if (events.isEmpty) {
          final searchTerm = query.trim().isEmpty ? 'recent events' : '"$query"';
          _errorMessage = 'No events found for $searchTerm in $_selectedSeason';
          } else {
            _errorMessage = ''; // Clear error message when events are found
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error searching events: ${e.toString()}';
        _events = [];
      });
    }
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events',
            style: AppConstants.headline4.copyWith(
              fontWeight: FontWeight.bold,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Find VEX IQ competitions and events',
            style: AppConstants.bodyText2.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          _buildSeasonSelector(),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              Expanded(
      child: TextField(
        controller: _searchController,
                  focusNode: _searchFocusNode,
        decoration: InputDecoration(
                    hintText: 'Search events by name...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppConstants.vexIQOrange,
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
                  },
                  onSubmitted: _searchEvents,
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              ElevatedButton(
                onPressed: _isLoading 
                    ? null 
                    : () => _searchEvents(_searchController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.vexIQOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingM,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Search'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSeasonSelector() {
    return Container(
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
            Icons.event_note,
            color: AppConstants.vexIQBlue,
            size: 20,
          ),
          const SizedBox(width: AppConstants.spacingS),
          Text(
            'Season:',
            style: AppConstants.bodyText2.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.vexIQBlue,
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSeason,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: AppConstants.vexIQBlue,
                ),
                style: AppConstants.bodyText2.copyWith(
                  color: AppConstants.vexIQBlue,
                  fontWeight: FontWeight.w600,
                ),
                items: ApiConfig.availableSeasons.keys.map((String seasonName) {
                  return DropdownMenuItem<String>(
                    value: seasonName,
                    child: Text(
                      seasonName,
                      style: AppConstants.bodyText2.copyWith(
                        color: AppConstants.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    final seasonId = ApiConfig.availableSeasons[newValue]!['vexiq']!;
                    _onSeasonChanged(newValue, seasonId);
                  }
                },
              ),
            ),
          ),
        ],
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
                        color: AppConstants.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingM),
                ElevatedButton.icon(
                  onPressed: () => _loadRecentEvents(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.vexIQOrange,
                    foregroundColor: Colors.white,
                  ),
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
              color: AppConstants.textPrimary,
                  fontWeight: FontWeight.bold,
            ),
          ),
              const SizedBox(height: AppConstants.spacingS),
              Text(
                'Searching through all events...',
                style: AppConstants.bodyText1.copyWith(
                  color: AppConstants.textSecondary,
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
                color: AppConstants.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
                'No Events Found',
                style: AppConstants.headline6.copyWith(
              color: AppConstants.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
                'Try a different search term or check back later',
            style: AppConstants.bodyText2.copyWith(
              color: AppConstants.textSecondary,
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
          itemCount: _events.length,
          itemBuilder: (context, index) {
            final event = _events[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getEventTypeColor(event.name),
                  child: Icon(
                    _getEventTypeIcon(event.name),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  event.name,
                  style: AppConstants.bodyText1.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_getEventLocation(event).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppConstants.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getEventLocation(event),
                              style: AppConstants.caption.copyWith(
                                color: AppConstants.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.start != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppConstants.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatEventDate(event.start!),
                            style: AppConstants.caption.copyWith(
                              color: AppConstants.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppConstants.vexIQOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'VEX IQ',
                        style: AppConstants.caption.copyWith(
                          color: AppConstants.vexIQOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Consumer<UserSettings>(
                      builder: (context, settings, child) {
                        final isFavorite = settings.isFavoriteEvent(event.sku);
                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : AppConstants.textSecondary,
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
                      color: AppConstants.textSecondary,
                    ),
                  ],
                ),
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
        ),
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
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.textPrimary,
        actions: [
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
} 