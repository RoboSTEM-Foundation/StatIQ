import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/screens/home_screen.dart';
import 'package:stat_iq/screens/teams_screen.dart';
import 'package:stat_iq/screens/events_screen.dart';
import 'package:stat_iq/screens/explore_screen.dart';
import 'package:stat_iq/screens/team_select_screen.dart';

import 'package:stat_iq/screens/settings_screen.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/special_teams_service.dart';
import 'package:stat_iq/services/notification_service.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';
import 'package:stat_iq/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await _initializeServices();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const TheCappedPinsApp());
}

Future<void> _initializeServices() async {
  try {
    // Initialize RobotEvents API with season mapping
    final initialized = await RobotEventsAPI.initializeAPI();
    
    if (initialized) {
      AppLogger.i('RobotEvents API initialized with season mapping');
    } else {
      AppLogger.w('API initialization failed');
    }
    
    // Initialize special teams service
    await SpecialTeamsService.instance.load();
    
    // Initialize notification service
    await NotificationService().initialize();
    AppLogger.i('Notification service initialized');
    
    // Check API configuration
    if (ApiConfig.isApiKeyConfigured) {
      AppLogger.d('API key is configured');
      // Check API status
      final status = await RobotEventsAPI.checkApiStatus();
      if (status['status'] == 'success') {
        AppLogger.i('API connection verified');
        AppLogger.d('   Available seasons: ${status['season_count']}');
      } else {
        AppLogger.w('API connection issue: ${status['message']}');
      }
    } else {
      AppLogger.w('API key not configured - using offline mode');
      AppLogger.d('   Set your API key in lib/constants/api_config.dart');
    }
    
  } catch (e) {
    AppLogger.e('Error initializing services', e);
  }
}

class TheCappedPinsApp extends StatelessWidget {
  const TheCappedPinsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserSettings>(
      future: UserSettings.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ChangeNotifierProvider<UserSettings>.value(
            value: snapshot.data!,
            child: Consumer<UserSettings>(
              builder: (context, userSettings, child) {
                return MaterialApp(
                  title: 'statIQ - VEX IQ Mix and Match',
                  debugShowCheckedModeBanner: false,
                  theme: _buildLightTheme(),
                  darkTheme: _buildDarkTheme(),
                  themeMode: userSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                  home: const MainNavigation(),
                  routes: {
                    '/home': (context) => const MainNavigation(),
                    '/teams': (context) => const MainNavigation(initialIndex: 1),
                    '/events': (context) => const MainNavigation(initialIndex: 2),
                    '/settings': (context) => const MainNavigation(initialIndex: 3),
                    '/team-select': (context) => const TeamSelectScreen(),
                  },
                );
              },
            ),
          );
        } else {
          // Show loading screen while UserSettings initializes
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppConstants.vexIQOrange,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Initializing statIQ',
                      style: AppConstants.headline6.copyWith(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'VEX IQ Mix and Match 2025-2026',
                      style: AppConstants.bodyText2.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  
  const MainNavigation({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  
  List<Widget> get _screens => [
    HomeScreen(onNavigateToTab: _navigateToTab),
    const ExploreScreen(),
    const TeamsScreen(),
    const EventsScreen(),
    // const SettingsScreen(),
  ];

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    NavigationItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
    ),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Teams',
    ),
    NavigationItem(
      icon: Icons.event_outlined,
      activeIcon: Icons.event,
      label: 'Events',
    ),
    // NavigationItem(
    //   icon: Icons.settings_outlined,
    //   activeIcon: Icons.settings,
    //   label: 'Settings',
    // ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppConstants.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          items: _navigationItems.map((item) {
            final isSelected = _navigationItems.indexOf(item) == _currentIndex;
            return BottomNavigationBarItem(
              icon: Icon(isSelected ? item.activeIcon : item.icon),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// Theme building methods
ThemeData _buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppConstants.vexIQOrange,
      brightness: Brightness.light,
    ),
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppConstants.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppConstants.headline5.copyWith(
        fontWeight: FontWeight.bold,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardTheme(
      elevation: AppConstants.elevationS,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
      ),
      margin: const EdgeInsets.all(AppConstants.spacingS),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConstants.vexIQOrange,
        foregroundColor: Colors.white,
        elevation: AppConstants.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingL,
          vertical: AppConstants.spacingM,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppConstants.vexIQOrange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        borderSide: const BorderSide(color: AppConstants.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        borderSide: BorderSide(color: AppConstants.vexIQOrange, width: 2),
      ),
      contentPadding: const EdgeInsets.all(AppConstants.spacingM),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppConstants.vexIQOrange,
      unselectedItemColor: AppConstants.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: AppConstants.caption.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppConstants.caption,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppConstants.vexIQOrange,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppConstants.textPrimary,
      contentTextStyle: AppConstants.bodyText2.copyWith(
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
      ),
    ),
  );
}

ThemeData _buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppConstants.vexIQOrange,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white),
      displayMedium: TextStyle(color: Colors.white),
      displaySmall: TextStyle(color: Colors.white),
      headlineLarge: TextStyle(color: Colors.white),
      headlineMedium: TextStyle(color: Colors.white),
      headlineSmall: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white),
      labelLarge: TextStyle(color: Colors.white),
      labelMedium: TextStyle(color: Colors.white),
      labelSmall: TextStyle(color: Colors.white),
    ),
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppConstants.headline5.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardTheme(
      elevation: AppConstants.elevationS,
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
      ),
      margin: const EdgeInsets.all(AppConstants.spacingS),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppConstants.vexIQOrange,
        foregroundColor: Colors.white,
        elevation: AppConstants.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingL,
          vertical: AppConstants.spacingM,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppConstants.vexIQOrange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
        borderSide: BorderSide(color: AppConstants.vexIQOrange, width: 2),
      ),
      contentPadding: const EdgeInsets.all(AppConstants.spacingM),
      fillColor: const Color(0xFF1A1A1A),
      filled: true,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: AppConstants.vexIQOrange,
      unselectedItemColor: const Color(0xFF9E9E9E),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: AppConstants.caption.copyWith(
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: AppConstants.caption,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppConstants.vexIQOrange,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      contentTextStyle: AppConstants.bodyText2.copyWith(
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
      ),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
  );
} 
