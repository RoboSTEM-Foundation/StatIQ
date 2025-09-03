import 'package:flutter/material.dart';

class AppConstants {
  // App Colors
  static const Color primaryColor = Colors.red;
  static const Color secondaryColor = Colors.blue;
  static const Color accentColor = Colors.orange;
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color backgroundLight = Colors.white;
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color infoColor = Colors.blue;
  
  // VEX IQ Colors
  static const Color vexIQRed = Color(0xFFE31E24);
  static const Color vexIQBlue = Color(0xFF0066CC);
  static const Color vexIQGreen = Color(0xFF00A651);
  static const Color vexIQYellow = Color(0xFFFFD700);
  static const Color vexIQOrange = Color(0xFFFF6600);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textDisabled = Color(0xFFE0E0E0);
  
  // Border Colors
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color dividerColor = Color(0xFFE0E0E0);
  
  // Shadow Colors
  static const Color shadowColor = Color(0x1F000000);
  static const Color shadowColorLight = Color(0x0A000000);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [vexIQRed, vexIQOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [vexIQBlue, vexIQGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Text Styles
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle headline4 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle headline5 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle headline6 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // Border Radius
  static const double borderRadiusS = 4.0;
  static const double borderRadiusM = 8.0;
  static const double borderRadiusL = 12.0;
  static const double borderRadiusXL = 16.0;
  static const double borderRadiusXXL = 24.0;
  
  // Elevation
  static const double elevationS = 2.0;
  static const double elevationM = 4.0;
  static const double elevationL = 8.0;
  static const double elevationXL = 16.0;
  
  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // API Constants
  static const String robotEventsBaseUrl = 'https://www.robotevents.com/api/v2';
  static const int vexIQProgramId = 41;
  static const int defaultVEXIQSeasonId = 192;
  
  // App Strings
  static const String appName = 'statIQ';
  static const String appDescription = 'VEX IQ RoboScout';
  static const String appVersion = '1.0.0';
  
  // Navigation Labels
  static const String homeLabel = 'Home';
  static const String teamsLabel = 'Teams';
  static const String eventsLabel = 'Events';
  static const String favoritesLabel = 'Favorites';
  static const String settingsLabel = 'Settings';
  
  // Error Messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String apiError = 'API error. Please try again later.';
  static const String timeoutMessage = 'Request timeout. Please try again.';
  static const String unknownError = 'An unknown error occurred.';
  static const String noDataError = 'No data available.';
  
  // Success Messages
  static const String dataLoadedSuccess = 'Data loaded successfully.';
  static const String settingsSavedSuccess = 'Settings saved successfully.';
  static const String favoriteAddedSuccess = 'Added to favorites.';
  static const String favoriteRemovedSuccess = 'Removed from favorites.';
  
  // Loading Messages
  static const String loadingTeams = 'Loading teams...';
  static const String loadingEvents = 'Loading events...';
  static const String loadingMatches = 'Loading matches...';
  static const String loadingRankings = 'Loading rankings...';
  static const String loadingSkills = 'Loading skills...';
  
  // Placeholder Text
  static const String searchTeamsHint = 'Search teams...';
  static const String searchEventsHint = 'Search events...';
  static const String noTeamsFound = 'No teams found';
  static const String noEventsFound = 'No events found';
  static const String noMatchesFound = 'No matches found';
  static const String noRankingsFound = 'No rankings found';
  static const String noSkillsFound = 'No skills found';
  
  // VEX IQ Specific
  static const List<String> vexIQGradeLevels = [
    'Elementary School',
    'Middle School',
  ];
  
  static const Map<String, String> vexIQGradeLevelAbbreviations = {
    'Elementary School': 'ES',
    'Middle School': 'MS',
  };
  
  static const Map<String, Color> vexIQGradeLevelColors = {
    'Elementary School': vexIQGreen,
    'Middle School': vexIQBlue,
  };
  
  // Award Types
  static const Map<String, double> awardWeights = {
    'excellence': 4.0,
    'champion': 3.0,
    'design': 2.5,
    'innovate': 2.0,
    'teamwork': 1.5,
    'default': 1.0,
  };
  
  // statIQ Score Ratings
  static const Map<String, Color> scoreRatingColors = {
    'Elite': Colors.purple,
    'Very High': Colors.red,
    'High': Colors.orange,
    'High Mid': Colors.yellow,
    'Mid': Colors.green,
    'Low Mid': Colors.blue,
    'Developing': Colors.grey,
  };
  
  // Match Round Names
  static const Map<String, String> matchRoundNames = {
    'none': 'None',
    'practice': 'Practice',
    'qualification': 'Qualification',
    'r128': 'Round of 128',
    'r64': 'Round of 64',
    'r32': 'Round of 32',
    'r16': 'Round of 16',
    'quarterfinals': 'Quarterfinals',
    'semifinals': 'Semifinals',
    'finals': 'Finals',
  };
  
  // Alliance Colors
  static const Map<String, Color> allianceColors = {
    'red': vexIQRed,
    'blue': vexIQBlue,
  };
} 