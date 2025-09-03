import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:stat_iq/screens/home_screen.dart';
import 'package:stat_iq/screens/teams_screen.dart';
import 'package:stat_iq/screens/events_screen.dart';

import 'package:stat_iq/screens/settings_screen.dart';
import 'package:stat_iq/services/robotevents_api.dart';
import 'package:stat_iq/services/user_settings.dart';
import 'package:stat_iq/services/notification_service.dart';
import 'package:stat_iq/constants/app_constants.dart';
import 'package:stat_iq/constants/api_config.dart';

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
      print('✅ RobotEvents API initialized with season mapping');
    } else {
      print('⚠️  API initialization failed');
    }
    
    // Initialize notification service
    // await NotificationService().initialize();
    // print('✅ Notification service initialized');
    
    // Check API configuration
    if (ApiConfig.isApiKeyConfigured) {
      print('✅ API key is configured');
      // Check API status
      final status = await RobotEventsAPI.checkApiStatus();
      if (status['status'] == 'success') {
        print('✅ API connection verified');
        print('   Available seasons: ${status['season_count']}');
      } else {
        print('⚠️  API connection issue: ${status['message']}');
      }
    } else {
      print('⚠️  API key not configured - using offline mode');
      print('   Set your API key in lib/constants/api_config.dart');
    }
    
  } catch (e) {
    print('❌ Error initializing services: $e');
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
            child: MaterialApp(
      title: 'statIQ - VEX IQ Mix and Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      ),
      home: const MainNavigation(),
              routes: {
                '/home': (context) => const MainNavigation(),
                '/teams': (context) => const MainNavigation(initialIndex: 1),
                '/events': (context) => const MainNavigation(initialIndex: 2),
                '/settings': (context) => const MainNavigation(initialIndex: 3),
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
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'VEX IQ Mix and Match 2025-2026',
                      style: AppConstants.bodyText2.copyWith(
                        color: AppConstants.textSecondary,
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
    const TeamsScreen(),
    const EventsScreen(),
    const SettingsScreen(),
  ];

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
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
    NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
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