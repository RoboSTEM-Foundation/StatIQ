# StatIQ Bug Report

This document outlines bugs and issues discovered during a comprehensive code review of the StatIQ Flutter application. Issues are categorized by severity and type.

---

## 🔴 CRITICAL ISSUES

### 1. API Keys Exposed in Source Code (SECURITY)
**Location:** `lib/constants/api_config.dart` (lines 10-22)

**Issue:** Production API keys are hardcoded directly in the source code and will be visible in version control history.

```dart
static const List<String> robotEventsApiKeys = [
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...',  // Full JWT token exposed
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...',  // Second JWT token exposed
];
```

**Impact:** Anyone with access to the repository can extract and misuse these API keys, potentially leading to rate limiting, quota exhaustion, or abuse of the RobotEvents API.

**Fix:** 
- Move API keys to environment variables or secure storage
- Use `flutter_dotenv` or `--dart-define` for build-time configuration
- Rotate compromised keys immediately

---

### 2. Incorrect Standard Deviation Calculation (MATH BUG)
**Location:** `lib/services/vex_iq_scoring.dart` (line 550)

**Issue:** The consistency bonus calculation uses an incorrect formula for standard deviation.

```dart
final variance = rankings.map((rank) => (rank - mean) * (rank - mean)).reduce((a, b) => a + b) / rankings.length;
final stdDev = variance > 0 ? (variance * variance) : 0; // BUG: Should be sqrt(variance)
```

**Current (Wrong):** `stdDev = variance * variance` (squares variance again)
**Correct:** `stdDev = sqrt(variance)` (takes square root of variance)

**Impact:** Teams with consistent performance receive incorrect scoring due to this mathematical error. The current formula produces wildly incorrect values.

**Fix:**
```dart
import 'dart:math' as math;
// ...
final stdDev = variance > 0 ? math.sqrt(variance) : 0.0;
```

---

## 🟠 HIGH SEVERITY ISSUES

### 3. Potential Null Pointer Exception in Team.fromJson
**Location:** `lib/models/team.dart` (line 44)

**Issue:** Debug print statement accesses potentially null values without null checks.

```dart
print('🔍 Team.fromJson Debug: json["number"] = ${json['number']}, json["team"] = ${json['team']}, final number = "$teamNumber"');
```

**Impact:** Excessive debug logging in production builds; could fail if JSON structure changes unexpectedly.

**Fix:** Either remove debug prints in production or add proper null safety:
```dart
// Remove or wrap in debug mode check:
assert(() {
  print('🔍 Team.fromJson Debug: ...');
  return true;
}());
```

---

### 4. Missing Import in vex_iq_scoring.dart
**Location:** `lib/services/vex_iq_scoring.dart` (line 1)

**Issue:** The file uses mathematical operations but doesn't import `dart:math` in some code paths.

**Impact:** If `sqrt` is used (as recommended fix for bug #2), it would fail. Currently the wrong formula avoids this, but the fix requires the import.

**Fix:** Add at the top of the file:
```dart
import 'dart:math' as math;
```

---

### 5. Grade Level Inconsistency
**Location:** `lib/services/vex_iq_scoring.dart` (lines 560-576)

**Issue:** The `getPerformanceTier` method accepts a `grade` parameter but doesn't use it. The Dart switch expression syntax used may not be compatible with all Dart versions.

```dart
static String getPerformanceTier(double percentage, String grade) {
  switch (percentage) {
    case >= 90:  // Modern Dart pattern matching
      return 'Elite';
    // ...
  }
}
```

**Impact:** 
- Grade-based tier adjustments aren't implemented despite method signature suggesting it
- Code may not compile on older Dart SDK versions

**Fix:** Either remove unused `grade` parameter or implement grade-based logic.

---

### 6. Hardcoded Default Season ID Mismatch
**Location:** `lib/constants/app_constants.dart` (line 140) vs `lib/constants/api_config.dart` (line 53)

**Issue:** Default VEX IQ season ID is inconsistent across files:
- `app_constants.dart`: `defaultVEXIQSeasonId = 192`
- `api_config.dart`: `currentVexIQSeasonId = 196`

**Impact:** Using the wrong season ID could fetch incorrect competition data.

**Fix:** Standardize to use `196` (Mix & Match 2025-2026) consistently.

---

## 🟡 MEDIUM SEVERITY ISSUES

### 7. Excessive Console Logging in Production
**Location:** Multiple files throughout the codebase

**Issue:** Extensive `print()` statements with emojis remain in production code:
- `lib/services/robotevents_api.dart` - 100+ print statements
- `lib/services/vex_iq_scoring.dart` - 40+ print statements
- `lib/services/special_teams_service.dart` - Debug prints

**Impact:** 
- Potential performance degradation
- Log pollution
- Information disclosure in production

**Fix:** Use `kDebugMode` checks or a proper logging framework:
```dart
import 'package:flutter/foundation.dart';
if (kDebugMode) {
  print('Debug message');
}
```

---

### 8. Unused Variables and Parameters
**Location:** Multiple locations

**Issue:** Several unused variables and parameters throughout the codebase:
- `lib/services/vex_iq_scoring.dart`: `grade` parameter in `getPerformanceTier` (line 560)
- `lib/screens/settings_screen.dart`: `_getThemeColorName` method (lines 264-270) is defined but never called

**Impact:** Dead code reduces maintainability and increases confusion.

**Fix:** Remove unused code or implement the intended functionality.

---

### 9. Potential Null Date Handling Issues
**Location:** `lib/screens/events_screen.dart` (lines 183-207)

**Issue:** Time frame filtering has edge cases where date comparisons may fail:

```dart
case 'This Season':
  if (_selectedSeasonId != 196) { // Not current season
    return true; // Show all events for past seasons
  }
  final seasonStart = DateTime(now.year, 8, 1);
  final seasonEnd = DateTime(now.year + 1, 6, 1);
```

**Impact:** Season boundaries are hardcoded to August-June, which may not align with actual VEX season dates.

**Fix:** Use dynamic season date ranges from the API or configuration.

---

### 10. Commented Out Imports
**Location:** Multiple files

**Issue:** Commented out imports suggest incomplete refactoring:
- `lib/screens/events_screen.dart` (line 6): `// import 'package:stat_iq/models/team.dart';`
- `lib/screens/team_details_screen.dart` (line 10): `// import 'package:stat_iq/constants/api_config.dart';`

**Impact:** Indicates potentially incomplete features or refactoring.

**Fix:** Either remove commented imports or complete the refactoring.

---

## 🟢 LOW SEVERITY ISSUES

### 11. Magic Numbers Without Constants
**Location:** Various locations

**Issue:** Magic numbers used without named constants:
- Skills score threshold: `300.0` (vex_iq_scoring.dart)
- Page limits: `50` pages, `250` per page (robotevents_api.dart)
- Animation delays: Various millisecond values

**Fix:** Define named constants for better maintainability.

---

### 12. Inconsistent Error Handling
**Location:** `lib/services/robotevents_api.dart`

**Issue:** Error handling varies between methods:
- Some methods throw exceptions: `getTeamMatches()` throws `Exception('API error: ${response.statusCode}')`
- Some return empty lists: `roboteventsRequest()` returns `[]` on error
- Some return null: `getTeamByNumber()` returns `null` on error

**Examples:**
```dart
// Throws exception (line 1507)
throw Exception('API error: ${response.statusCode}');

// Returns empty list (line 98)
return [];

// Returns null (line 2067)
return null;
```

**Impact:** Inconsistent error handling makes debugging harder and requires different error handling code at each call site.

**Fix:** Standardize error handling approach across the codebase. Consider:
- Create a Result<T, E> type for all API methods
- Or consistently throw exceptions and handle them uniformly
- Or consistently return empty/default values with logging

---

### 13. Missing Null Safety in Model Parsing
**Location:** `lib/models/team.dart` (lines 256-299)

**Issue:** `MatchTeam.fromJson` parsing could fail silently if data structure changes:

```dart
final teamInfo = teamData['team'] as Map<String, dynamic>?;
if (teamInfo != null) {
  // parsing logic
}
```

**Impact:** Data parsing is defensive but may hide API changes.

**Fix:** Add logging or monitoring for unexpected data structures.

---

### 14. Duplicate Code in Event Handling
**Location:** `lib/screens/events_screen.dart`

**Issue:** Similar event filtering logic is repeated in multiple methods:
- `_applyClientSideFilters`
- `_filterCurrentEvents`
- `_getEventLevelLabel`

**Impact:** Code duplication increases maintenance burden.

**Fix:** Extract common logic into reusable helper methods.

---

### 15. Widget Build Method Too Long
**Location:** `lib/screens/team_details_screen.dart`, `lib/screens/events_screen.dart`

**Issue:** Some widget build methods exceed 100+ lines, making them hard to maintain and test.

**Impact:** Reduced code readability and maintainability.

**Fix:** Extract smaller, focused widgets for better composition.

---

## 📋 TESTING ISSUES

### 16. Limited Test Coverage
**Location:** `test/` directory

**Issue:** Only one test file exists (`test/models_test.dart`) covering basic model parsing.

**Missing tests for:**
- API service methods
- Scoring calculations
- Screen widgets
- Edge cases in data parsing

**Fix:** Add comprehensive unit, widget, and integration tests.

---

## 🔧 RECOMMENDATIONS

### Immediate Actions:
1. **URGENT:** Rotate exposed API keys and implement secure key management
2. **URGENT:** Fix the standard deviation calculation bug
3. Remove or guard debug print statements

### Short-term Improvements:
4. Add unit tests for scoring algorithms
5. Standardize season ID constants
6. Clean up commented/unused code

### Long-term Improvements:
7. Implement proper logging framework
8. Add comprehensive test coverage
9. Refactor large methods into smaller components
10. Consider using code generation for JSON serialization

---

## Summary Table

| # | Issue | Severity | Type | File |
|---|-------|----------|------|------|
| 1 | API Keys in Source | 🔴 Critical | Security | api_config.dart |
| 2 | Wrong StdDev Calculation | 🔴 Critical | Math Bug | vex_iq_scoring.dart |
| 3 | Debug Prints in Production | 🟠 High | Code Quality | team.dart |
| 4 | Missing math Import | 🟠 High | Compilation | vex_iq_scoring.dart |
| 5 | Unused Grade Parameter | 🟠 High | Logic Bug | vex_iq_scoring.dart |
| 6 | Season ID Mismatch | 🟠 High | Config | app_constants.dart |
| 7 | Excessive Logging | 🟡 Medium | Performance | Multiple |
| 8 | Unused Code | 🟡 Medium | Maintainability | Multiple |
| 9 | Date Handling | 🟡 Medium | Logic | events_screen.dart |
| 10 | Commented Imports | 🟡 Medium | Code Quality | Multiple |
| 11 | Magic Numbers | 🟢 Low | Maintainability | Multiple |
| 12 | Inconsistent Errors | 🟢 Low | Code Quality | robotevents_api.dart |
| 13 | Model Parsing | 🟢 Low | Robustness | team.dart |
| 14 | Duplicate Code | 🟢 Low | Maintainability | events_screen.dart |
| 15 | Long Methods | 🟢 Low | Code Quality | Multiple |
| 16 | Low Test Coverage | 🟡 Medium | Testing | test/ |

---

*Report generated on: December 4, 2024*
*Reviewed by: Automated Code Analysis*
