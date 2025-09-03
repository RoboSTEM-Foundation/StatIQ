import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stat_iq/constants/app_constants.dart';

class Helpers {
  // Date formatting
  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }
  
  static String formatTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('HH:mm').format(date);
  }
  
  // Number formatting
  static String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }
  
  static String formatDecimal(double number, {int decimalPlaces = 1}) {
    return NumberFormat('#,##0.${'0' * decimalPlaces}').format(number);
  }
  
  static String formatPercentage(double percentage) {
    return '${formatDecimal(percentage)}%';
  }
  
  // String utilities
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  static String slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '-')
        .trim();
  }
  
  // Color utilities
  static Color getScoreColor(String rating) {
    return AppConstants.scoreRatingColors[rating] ?? Colors.grey;
  }
  
  static Color getGradeLevelColor(String gradeLevel) {
    return AppConstants.vexIQGradeLevelColors[gradeLevel] ?? Colors.grey;
  }
  
  static Color getAllianceColor(String alliance) {
    return AppConstants.allianceColors[alliance.toLowerCase()] ?? Colors.grey;
  }
  
  // Validation
  static bool isValidTeamNumber(String teamNumber) {
    return RegExp(r'^\d+[A-Z]?$').hasMatch(teamNumber);
  }
  
  static bool isValidEventSku(String sku) {
    return RegExp(r'^RE-[A-Z0-9]+$').hasMatch(sku);
  }
  
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }
  
  // Time utilities
  static String getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
  
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
  
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
           date.isBefore(weekEnd.add(const Duration(days: 1)));
  }
  
  // List utilities
  static List<T> removeDuplicates<T>(List<T> list) {
    return list.toSet().toList();
  }
  
  static List<T> sortByProperty<T>(List<T> list, dynamic Function(T) property) {
    list.sort((a, b) => property(a).compareTo(property(b)));
    return list;
  }
  
  static List<T> filterByProperty<T>(List<T> list, bool Function(T) predicate) {
    return list.where(predicate).toList();
  }
  
  // Map utilities
  static Map<K, V> sortMapByValue<K, V>(Map<K, V> map, int Function(V, V) compare) {
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => compare(a.value, b.value));
    return Map.fromEntries(sortedEntries);
  }
  
  static Map<K, V> sortMapByKey<K, V>(Map<K, V> map, int Function(K, K) compare) {
    final sortedEntries = map.entries.toList()
      ..sort((a, b) => compare(a.key, b.key));
    return Map.fromEntries(sortedEntries);
  }
  
  // Error handling
  static String getErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error.toString().contains('NetworkException')) {
      return AppConstants.networkError;
    }
    if (error.toString().contains('TimeoutException')) {
      return AppConstants.timeoutMessage;
    }
    return AppConstants.unknownError;
  }
  
  // File utilities
  static String getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last : '';
  }
  
  static String getFileName(String filePath) {
    return filePath.split('/').last;
  }
  
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  // Animation utilities
  static Duration getAnimationDuration(AnimationSpeed speed) {
    switch (speed) {
      case AnimationSpeed.fast:
        return AppConstants.animationFast;
      case AnimationSpeed.normal:
        return AppConstants.animationNormal;
      case AnimationSpeed.slow:
        return AppConstants.animationSlow;
    }
  }
}

enum AnimationSpeed {
  fast,
  normal,
  slow,
} 