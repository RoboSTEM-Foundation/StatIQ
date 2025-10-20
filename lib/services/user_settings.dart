import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserSettings extends ChangeNotifier {
  static const String _gradeLevelKey = 'grade_level';
  static const String _selectedSeasonIdKey = 'selected_season_id';
  static const String _minimalisticKey = 'minimalistic';
  static const String _vexIQScoreKey = 'vex_iq_score';
  static const String _themeColorKey = 'theme_color';
  static const String _favoriteTeamsKey = 'favorite_teams';
  static const String _favoriteEventsKey = 'favorite_events';
  static const String _robotEventsApiKeyKey = 'robotevents_api_key';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _myTeamKey = 'my_team';
  
  static UserSettings? _instance;
  static SharedPreferences? _prefs;
  
  // Default values
  String _gradeLevel = 'Middle School';
  int _selectedSeasonId = 192; // Default VEX IQ season
  bool _minimalistic = true;
  bool _vexIQScore = true;
  Color _themeColor = Colors.red;
  List<String> _favoriteTeams = [];
  List<String> _favoriteEvents = [];
  String? _robotEventsApiKey;
  bool _isDarkMode = false;
  String? _myTeam;
  
  // Getters
  String get gradeLevel => _gradeLevel;
  int get selectedSeasonId => _selectedSeasonId;
  bool get minimalistic => _minimalistic;
  bool get vexIQScore => _vexIQScore;
  Color get themeColor => _themeColor;
  List<String> get favoriteTeams => List.unmodifiable(_favoriteTeams);
  List<String> get favoriteEvents => List.unmodifiable(_favoriteEvents);
  String? get robotEventsApiKey => _robotEventsApiKey;
  bool get isDarkMode => _isDarkMode;
  String? get myTeam => _myTeam;
  
  // Available grade levels for VEX IQ
  static const List<String> availableGradeLevels = [
    'Elementary School',
    'Middle School',
  ];
  
  // Available season IDs (will be updated dynamically)
  static Map<String, int> seasonIds = {
    'Elementary School': 192,
    'Middle School': 192,
  };
  
  UserSettings._();
  
  static Future<UserSettings> getInstance() async {
    if (_instance == null) {
      _instance = UserSettings._();
      _prefs = await SharedPreferences.getInstance();
      await _instance!._loadSettings();
    }
    return _instance!;
  }
  
  Future<void> _loadSettings() async {
    _minimalistic = _prefs!.getBool(_minimalisticKey) ?? true;
    _isDarkMode = _prefs!.getBool(_isDarkModeKey) ?? false;
    _gradeLevel = _prefs!.getString(_gradeLevelKey) ?? 'Middle School';
    _selectedSeasonId = _prefs!.getInt(_selectedSeasonIdKey) ?? 192;
    _vexIQScore = _prefs!.getBool(_vexIQScoreKey) ?? true;
    _themeColor = Color(_prefs!.getInt(_themeColorKey) ?? Colors.red.value);
    _favoriteTeams = _prefs!.getStringList(_favoriteTeamsKey) ?? [];
    _favoriteEvents = _prefs!.getStringList(_favoriteEventsKey) ?? [];
    _robotEventsApiKey = _prefs!.getString(_robotEventsApiKeyKey);
    _myTeam = _prefs!.getString(_myTeamKey);
    notifyListeners();
  }
  
  Future<void> _saveSettings() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    
    await _prefs!.setBool(_minimalisticKey, _minimalistic);
    await _prefs!.setBool(_isDarkModeKey, _isDarkMode);
    await _prefs!.setString(_gradeLevelKey, _gradeLevel);
    await _prefs!.setInt(_selectedSeasonIdKey, _selectedSeasonId);
    await _prefs!.setBool(_vexIQScoreKey, _vexIQScore);
    await _prefs!.setInt(_themeColorKey, _themeColor.value);
    await _prefs!.setStringList(_favoriteTeamsKey, _favoriteTeams);
    await _prefs!.setStringList(_favoriteEventsKey, _favoriteEvents);
    if (_robotEventsApiKey != null) {
      await _prefs!.setString(_robotEventsApiKeyKey, _robotEventsApiKey!);
    }
    if (_myTeam != null) {
      await _prefs!.setString(_myTeamKey, _myTeam!);
    }
    notifyListeners();
  }
  
  // Setters
  Future<void> setGradeLevel(String gradeLevel) async {
    if (_gradeLevel != gradeLevel) {
      _gradeLevel = gradeLevel;
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> setSelectedSeasonId(int seasonId) async {
    if (_selectedSeasonId != seasonId) {
      _selectedSeasonId = seasonId;
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> setMinimalistic(bool minimalistic) async {
    if (_minimalistic != minimalistic) {
      _minimalistic = true; // Always true
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> setVEXIQScore(bool vexIQScore) async {
    if (_vexIQScore != vexIQScore) {
      _vexIQScore = vexIQScore;
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> setThemeColor(Color color) async {
    if (_themeColor != color) {
      _themeColor = color;
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> setRobotEventsApiKey(String? apiKey) async {
    if (_robotEventsApiKey != apiKey) {
      _robotEventsApiKey = apiKey;
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      await _saveSettings();
      notifyListeners();
    }
  }
  
  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveSettings();
    notifyListeners();
  }
  
  // Favorite teams management
  Future<void> addFavoriteTeam(String teamNumber) async {
    if (!_favoriteTeams.contains(teamNumber)) {
      _favoriteTeams.add(teamNumber);
      _favoriteTeams.sort();
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> removeFavoriteTeam(String teamNumber) async {
    if (_favoriteTeams.remove(teamNumber)) {
      await _saveSettings();
      notifyListeners();
    }
  }
  
  bool isFavoriteTeam(String teamNumber) {
    return _favoriteTeams.contains(teamNumber);
  }
  
  // Favorite events management
  Future<void> addFavoriteEvent(String eventSku) async {
    if (!_favoriteEvents.contains(eventSku)) {
      _favoriteEvents.add(eventSku);
      _favoriteEvents.sort();
      await _saveSettings();
      notifyListeners();
    }
  }
  
  Future<void> removeFavoriteEvent(String eventSku) async {
    if (_favoriteEvents.remove(eventSku)) {
      await _saveSettings();
      notifyListeners();
    }
  }
  
  bool isFavoriteEvent(String eventSku) {
    return _favoriteEvents.contains(eventSku);
  }
  
  // Update season IDs from API
  static void updateSeasonIds(Map<String, int> newSeasonIds) {
    seasonIds = Map.from(newSeasonIds);
  }
  
  // Get current season ID for selected grade level
  int getCurrentSeasonId() {
    return seasonIds[_gradeLevel] ?? _selectedSeasonId;
  }
  
  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _gradeLevel = 'Middle School';
    _selectedSeasonId = 192;
    _minimalistic = true;
    _vexIQScore = true;
    _themeColor = Colors.red;
    _favoriteTeams = [];
    _favoriteEvents = [];
    _robotEventsApiKey = null;
    _isDarkMode = false;
    _myTeam = null;
    
    await _saveSettings();
    notifyListeners();
  }
  
  // Export settings as JSON
  Map<String, dynamic> toJson() {
    return {
      'gradeLevel': _gradeLevel,
      'selectedSeasonId': _selectedSeasonId,
      'minimalistic': _minimalistic,
      'vexIQScore': _vexIQScore,
      'themeColor': _themeColor.value,
      'favoriteTeams': _favoriteTeams,
      'favoriteEvents': _favoriteEvents,
      'robotEventsApiKey': _robotEventsApiKey,
      'isDarkMode': _isDarkMode,
      'myTeam': _myTeam,
    };
  }
  
  // Import settings from JSON
  Future<void> fromJson(Map<String, dynamic> json) async {
    _gradeLevel = json['gradeLevel'] ?? 'Middle School';
    _selectedSeasonId = json['selectedSeasonId'] ?? 192;
    _minimalistic = json['minimalistic'] ?? true;
    _vexIQScore = json['vexIQScore'] ?? true;
    _themeColor = Color(json['themeColor'] ?? Colors.red.value);
    _favoriteTeams = List<String>.from(json['favoriteTeams'] ?? []);
    _favoriteEvents = List<String>.from(json['favoriteEvents'] ?? []);
    _robotEventsApiKey = json['robotEventsApiKey'];
    _isDarkMode = json['isDarkMode'] ?? false;
    _myTeam = json['myTeam'];
    
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMyTeam(String? teamNumber) async {
    if (_myTeam != teamNumber) {
      _myTeam = teamNumber;
      await _saveSettings();
      notifyListeners();
    }
  }
} 