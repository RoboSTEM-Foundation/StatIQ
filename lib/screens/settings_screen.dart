import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/team_sync_service.dart';
import 'package:stat_iq/services/optimized_team_search.dart';
import 'package:stat_iq/screens/credits_screen.dart';
import 'package:stat_iq/widgets/optimized_team_search_widget.dart';
import 'package:stat_iq/utils/theme_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    final status = await TeamSyncService.getSyncStatus();
    if (mounted) {
      setState(() {
        _syncStatus = status;
      });
    }
  }

  String _formatLastSyncTime(DateTime? lastSync) {
    if (lastSync == null) {
      return 'Never synced';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inDays > 0) {
      return 'Last synced ${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return 'Last synced ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return 'Last synced ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Last synced just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserSettings>(
      builder: (context, userSettings, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            children: [
              _buildPreferencesSection(userSettings),
              const SizedBox(height: AppConstants.spacingL),
              _buildDataSection(),
              const SizedBox(height: AppConstants.spacingL),
              _buildAboutSection(),
            ],
          ),
        );
      },
    );
  }



  Widget _buildPreferencesSection(UserSettings userSettings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferences',
              style: AppConstants.headline5.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('My Team'),
              subtitle: Text(userSettings.myTeam ?? 'Not Set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showMyTeamDialog(context, userSettings);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Manage push notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showNotificationsDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showLanguageDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between light and dark themes'),
              trailing: Switch(
                value: userSettings.isDarkMode,
                onChanged: (value) async {
                  await userSettings.setDarkMode(value);
                },
                activeColor: AppConstants.vexIQOrange,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Default Location'),
              subtitle: const Text('Set your preferred region'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showLocationDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data & Storage',
              style: AppConstants.headline5.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear Cache'),
              subtitle: const Text('Free up storage space'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showClearCacheDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Sync Data'),
              subtitle: Text(_syncStatus != null 
                  ? _formatLastSyncTime(_syncStatus!['lastSync'])
                  : 'Loading...'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showSyncDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: AppConstants.headline5.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About statIQ'),
              subtitle: const Text('Version 1.0.0'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Credits'),
              subtitle: const Text('Special thanks to contributors'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreditsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showPrivacyDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showTermsDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Send Feedback'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showFeedbackDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeColorName(Color color) {
    if (color == AppConstants.vexIQBlue) return 'VEX IQ Blue';
    if (color == AppConstants.vexIQGreen) return 'VEX IQ Green';
    if (color == AppConstants.vexIQOrange) return 'VEX IQ Orange';
    if (color == AppConstants.vexIQRed) return 'VEX IQ Red';
    return 'Custom';
  }

  void _showMyTeamDialog(BuildContext context, UserSettings userSettings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Your Team'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: OptimizedTeamSearchWidget(
            onTeamSelected: (team) {
              userSettings.setMyTeam(team.number);
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    final userSettings = Provider.of<UserSettings>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notifications'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Consumer<UserSettings>(
                builder: (context, settings, child) => SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Get notified before matches'),
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
                    await settings.setNotificationsEnabled(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (userSettings.notificationsEnabled) ...[
                const Divider(),
                Consumer<UserSettings>(
                  builder: (context, settings, child) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications for:',
                        style: AppConstants.bodyText1.copyWith(
                          color: ThemeUtils.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (settings.myTeam != null) ...[
                        ListTile(
                          leading: const Icon(Icons.groups, color: AppConstants.vexIQBlue),
                          title: Text('Team ${settings.myTeam}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showMyTeamDialog(context, settings);
                            },
                          ),
                        ),
                      ] else ...[
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Add Team'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showMyTeamDialog(context, settings);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Consumer<UserSettings>(
                  builder: (context, settings, child) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Minutes before match:',
                        style: AppConstants.bodyText1.copyWith(
                          color: ThemeUtils.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [5, 10, 15, 30, 60].map((minutes) {
                          return ChoiceChip(
                            label: Text('${minutes}m'),
                            selected: settings.notificationMinutesBefore == minutes,
                            onSelected: (selected) async {
                              if (selected) {
                                await settings.setNotificationMinutesBefore(minutes);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language'),
        content: const Text('Language settings coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Location'),
        content: const Text('Location settings coming soon...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data including team lists, events, and search indexes. You will need to re-download data when you next use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearCache(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Clearing cache...'),
          ],
        ),
      ),
    );

    try {
      // Clear SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear team search cache
      await OptimizedTeamSearch.clearCache();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Refresh sync status
        await _loadSyncStatus();
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cache Cleared'),
            content: const Text('All cached data has been cleared successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Failed'),
            content: Text('Failed to clear cache: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Team List'),
        content: const Text('This will download the latest team database from GitHub. This may take a few moments.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _syncTeamList(context);
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncTeamList(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Syncing Team List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Downloading team data from GitHub...'),
            const SizedBox(height: 8),
            Text('This may take up to 2 minutes for large files', 
                 style: TextStyle(fontSize: 12, color: ThemeUtils.getMutedTextColor(context))),
          ],
        ),
      ),
    );

    try {
      // Force sync the team list
      await TeamSyncService.syncTeamList();
      
      // Reinitialize the search with new data
      await OptimizedTeamSearch.initialize();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Refresh sync status
        await _loadSyncStatus();
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Complete'),
            content: const Text('Team list has been successfully updated!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Failed'),
            content: Text('Failed to sync team list: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About statIQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VEX IQ RoboScout',
              style: AppConstants.headline6.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingS),
            const Text('Version 1.0.0'),
            const SizedBox(height: AppConstants.spacingS),
            const Text(
              'A modern VEX IQ scouting app for tracking teams, events, and performance analytics.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'We do not collect any personal data from users. '
          'All data is stored locally on your device and is not transmitted to our servers. '
          'The app only fetches public VEX IQ competition data from RobotEvents.com.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const Text(
          'By using this app, you agree not to abuse the RobotEvents API. '
          'Please use the app responsibly and do not attempt to overload or misuse the API endpoints. '
          'The app is provided as-is for educational and scouting purposes.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: const Text(
          'Have feedback, suggestions, or found a bug? '
          'Message @_lvdg on Discord!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
} 