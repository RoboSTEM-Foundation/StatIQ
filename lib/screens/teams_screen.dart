import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/models/team.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/user_settings.dart';

import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/widgets/vex_iq_score_card.dart';
import 'package:stat_iq/screens/team_details_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<Team> _teams = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';
  int? _selectedSeasonId;
  
  @override
  void initState() {
    super.initState();
    _selectedSeasonId = ApiConfig.getSelectedSeasonId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchTeams(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _teams = [];
        _hasSearched = false;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = '';
    });

    try {
      final teams = await RobotEventsAPI.searchTeams(
        teamNumber: query.trim().toUpperCase(),
        seasonId: _selectedSeasonId,
      );

      setState(() {
        _teams = teams;
        _isLoading = false;
        if (teams.isEmpty) {
          _errorMessage = 'No teams found for "$query"';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error searching teams: ${e.toString()}';
        _teams = [];
      });
    }
  }

  void _showTeamDetails(Team team) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamDetailsScreen(team: team),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSettings>(
      builder: (context, userSettings, child) {
        return SafeArea(
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Teams'),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: Column(
              children: [
                _buildSearchSection(),
                if (!ApiConfig.isApiKeyConfigured) _buildApiKeyWarning(),
                if (_isLoading) 
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildTeamsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Enter team number (e.g., 60666X)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchTeams('');
                        _searchFocusNode.unfocus();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
                borderSide: BorderSide(color: AppConstants.vexIQOrange),
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _searchTeams,
            onChanged: (value) {
              setState(() {}); // Update UI for clear button
            },
          ),
          const SizedBox(height: AppConstants.spacingS),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppConstants.textSecondary,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  'Searching VEX IQ teams only',
                  style: AppConstants.caption.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyWarning() {
    if (ApiConfig.isApiKeyConfigured) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
        border: Border.all(color: Colors.orange.shade200),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'API Key Required',
                  style: AppConstants.bodyText1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  'Set your RobotEvents API key in lib/constants/api_config.dart',
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

  Widget _buildTeamsList() {
    if (_errorMessage.isNotEmpty) {
      return Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search,
                  size: 64,
                  color: AppConstants.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: AppConstants.spacingM),
                Text(
                  'Enter a team number to search',
                  style: AppConstants.headline6.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  'Search for VEX IQ teams',
                  style: AppConstants.bodyText2.copyWith(
                    color: AppConstants.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_teams.isEmpty && !_isLoading) {
      return Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    color: AppConstants.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'No Teams Found',
                    style: AppConstants.headline6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Try a different team number or check the spelling',
                    style: AppConstants.bodyText2.copyWith(
                      color: AppConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
        itemCount: _teams.length,
        itemBuilder: (context, index) {
          final team = _teams[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
            elevation: AppConstants.elevationS,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
            ),
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
                    // statIQ Score
                    VEXIQScoreCard(
                      team: team,
                      seasonId: _selectedSeasonId,
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
      ),
    );
  }
}