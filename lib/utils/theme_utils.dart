import 'package:flutter/material.dart';

class ThemeUtils {
  /// Returns white text color in dark mode, or the theme's text color in light mode
  static Color getTextColor(BuildContext context, {double opacity = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withOpacity(opacity);
    }
    return Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(opacity) ?? 
           Colors.black.withOpacity(opacity);
  }

  /// Returns white for secondary text in dark mode, or the theme's secondary color in light mode
  static Color getSecondaryTextColor(BuildContext context, {double opacity = 0.7}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withOpacity(opacity);
    }
    return Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(opacity) ?? 
           Colors.grey.withOpacity(opacity);
  }

  /// Returns white for muted text in dark mode, or the theme's muted color in light mode
  static Color getMutedTextColor(BuildContext context, {double opacity = 0.5}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withOpacity(opacity);
    }
    return Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(opacity) ?? 
           Colors.grey.withOpacity(opacity);
  }

  /// Returns white for very muted text in dark mode, or the theme's very muted color in light mode
  static Color getVeryMutedTextColor(BuildContext context, {double opacity = 0.3}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return Colors.white.withOpacity(opacity);
    }
    return Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(opacity) ?? 
           Colors.grey.withOpacity(opacity);
  }
}
