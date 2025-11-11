/*
 * Event search implementation adapted from VRC RoboScout by William Castro
 * Original Swift codebase: https://github.com/CastroWill/VRC-RoboScout
 * Used with permission - credit given as requested
 * 
 * The web scraping approach for event search was taken from the Swift implementation
 * and adapted for VEX IQ and Flutter/Dart
 */

import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../models/team.dart';
import '../models/event.dart';
import 'dart:math' as math;

class RobotEventsAPI {
  static const Duration _requestTimeout = Duration(seconds: 30);
  
  // Initialize API - generate season ID mappings (matches Swift implementation)
  static Future<bool> initializeAPI() async {
    try {
      await ApiConfig.generateSeasonIdMap();
      return true;
    } catch (e) {
      print('Error initializing API: $e');
      return false;
    }
  }
  
  // Check API status
  static Future<Map<String, dynamic>> checkApiStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.robotEventsBaseUrl}/seasons/'),
        headers: ApiConfig.robotEventsHeaders,
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'status': 'success',
          'message': 'API connection successful',
          'season_count': (data['data'] as List).length,
        };
      } else {
        return {
          'status': 'error',
          'message': 'API returned status code ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: $e',
      };
    }
  }
  
  // Core robotevents_request function (matches Swift implementation exactly)
  static Future<List<dynamic>> roboteventsRequest({
    required String requestUrl,
    Map<String, dynamic>? params,
  }) async {
    try {
      // Build URL with parameters (supports repeated keys like level[]=Signature)
      final uriWithParams = _buildUriWithParams(
        baseUrl: '${ApiConfig.robotEventsBaseUrl}$requestUrl',
        params: params,
      );
      
      print('API Request: $uriWithParams');
      
      final response = await http.get(
        uriWithParams,
        headers: ApiConfig.robotEventsHeaders,
      ).timeout(_requestTimeout);
      
      print('API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final data = jsonData['data'] as List<dynamic>;
        print('API returned ${data.length} results');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Check your API key');
      } else if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded');
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      print('robotevents_request error: $e');
      return [];
    }
  }

  // Build a Uri that supports repeated query keys for array params (e.g., level[]=Signature)
  static Uri _buildUriWithParams({required String baseUrl, Map<String, dynamic>? params}) {
    if (params == null || params.isEmpty) {
      return Uri.parse(baseUrl);
    }

    final queryParts = <String>[];
    params.forEach((key, value) {
      if (value == null) return;

      if (value is List) {
        final keyName = key.endsWith('[]') ? key : '${key}[]';
        for (final item in value) {
          queryParts.add('${Uri.encodeQueryComponent(keyName)}=${Uri.encodeQueryComponent(item.toString())}');
        }
      } else {
        queryParts.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value.toString())}');
      }
    });

    final separator = baseUrl.contains('?') ? '&' : '?';
    return Uri.parse('$baseUrl$separator${queryParts.join('&')}');
  }
  
  // Search teams (matches Swift Team.fetch_info implementation exactly)
  static Future<List<Team>> searchTeams({
    String? teamNumber,
    int? teamId,
    int? seasonId,
  }) async {
    print('=== Team Search Debug ===');
    print('Team Number: $teamNumber');
    print('Team ID: $teamId');
    print('Season ID: $seasonId');
    
    final params = ApiConfig.getTeamSearchParams(
      teamNumber: teamNumber,
      teamId: teamId,
      seasonId: seasonId,
    );
    
    print('Search params: $params');
    
    final data = await roboteventsRequest(
      requestUrl: '/teams',
      params: params,
    );
    
    print('Team lookup returned ${data.length} results for ${teamNumber?.isNotEmpty == true ? "number $teamNumber" : "ID $teamId"}');
    if (data.isNotEmpty) {
      print('🔍 First team result: ${data.first}');
    } else {
      print('🔍 No team results found for search: $params');
    }
    
    final teams = <Team>[];
    for (final teamData in data) {
      try {
        final team = Team.fromJson(teamData);
        
        // Filter to VEX IQ only
        final programId = teamData['program']?['id'] as int?;
        if (programId == ApiConfig.vexIQProgramId) {
          teams.add(team);
          print('Added VEX IQ team: ${team.number} - ${team.name} (Grade: ${team.grade})');
        }
      } catch (e) {
        print('Error parsing team data: $e');
      }
    }
    
    print('Filtered to ${teams.length} VEX IQ teams');
    print('=== End Team Search Debug ===');
    
    return teams;
  }
  
  // Get team events (matches Swift fetch_events implementation)
  static Future<List<Event>> getTeamEvents({
    required int teamId,
    int? seasonId,
  }) async {
    print('=== Team Events Debug ===');
    print('Team ID: $teamId');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    
    final params = ApiConfig.getTeamEventsParams(
      teamId: teamId,
      seasonId: seasonId,
    );
    
    final data = await roboteventsRequest(
      requestUrl: '/events',
      params: params,
    );
    
    print('Events API returned ${data.length} events');
    
    final events = <Event>[];
    for (final eventData in data) {
      try {
        final event = Event.fromJson(eventData);
        events.add(event);
    } catch (e) {
        print('Error parsing event data: $e');
      }
    }
    
    print('Total events loaded: ${events.length}');
    print('=== End Team Events Debug ===');
    
    return events;
  }
  
  // Get team awards (matches Swift fetch_awards implementation)
  static Future<List<dynamic>> getTeamAwards({
    required int teamId,
    int? seasonId,
  }) async {
    print('=== Team Awards Debug ===');
    print('Team ID: $teamId');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    
    final params = ApiConfig.getTeamAwardsParams(
      teamId: teamId,
      seasonId: seasonId,
    );
    
    final data = await roboteventsRequest(
      requestUrl: '/teams/$teamId/awards',
      params: params,
    );
    
    print('Awards API returned ${data.length} awards');
    print('=== End Team Awards Debug ===');
    
    return data;
  }
  
  // Get team rankings (matches Swift average_ranking implementation)
  static Future<List<dynamic>> getTeamRankings({
    required int teamId,
    int? seasonId,
  }) async {
    print('=== Team Rankings Debug ===');
    print('Team ID: $teamId');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    
    final params = ApiConfig.getTeamRankingsParams(
      teamId: teamId,
      seasonId: seasonId,
    );
    
    final data = await roboteventsRequest(
      requestUrl: '/teams/$teamId/rankings',
      params: params,
    );
    
    print('Rankings API returned ${data.length} ranking records');
    print('=== End Team Rankings Debug ===');
    
    return data;
  }
  
  // Get team skills data (try multiple endpoints)
  static Future<List<dynamic>> getTeamWorldSkills({
    required int teamId,
    int? seasonId,
  }) async {
    print('=== Team Skills Debug ===');
    print('Team ID: $teamId');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    
    final targetSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
    
    // Try team-specific skills endpoint first
    try {
      final params = {
        'season': targetSeasonId,
      };
      
      print('Trying /teams/$teamId/skills endpoint...');
      final data = await roboteventsRequest(
        requestUrl: '/teams/$teamId/skills',
        params: params,
      );
      
      print('Team Skills API returned ${data.length} records');
      print('=== End Team Skills Debug ===');
      return data;
    } catch (e) {
      print('Team skills endpoint failed: $e');
  }

    // Fallback: Try general skills endpoint with team filter
    try {
      final params = {
        'team': teamId,
        'season': targetSeasonId,
        'program': ApiConfig.getSelectedProgramId(),
      };
      
      print('Trying /skills endpoint with team filter...');
      final data = await roboteventsRequest(
        requestUrl: '/skills',
        params: params,
      );
      
      print('Skills API returned ${data.length} records');
      print('=== End Team Skills Debug ===');
      return data;
    } catch (e) {
      print('Skills endpoint failed: $e');
    }
    
    print('No skills data available - returning empty list');
    print('=== End Team Skills Debug ===');
    return [];
  }
  
  // Get world skills rankings (for calculating percentiles)
  static Future<List<dynamic>> getWorldSkillsRankings({
    int? seasonId,
    int page = 1,
    String gradeLevel = 'Middle School',
  }) async {
    final effectiveSeasonId = seasonId ?? ApiConfig.currentVexIQSeasonId;
    
    // Map UI grade level names to API parameter values
    String apiGradeLevel = gradeLevel;
    if (gradeLevel == 'Elementary School') {
      apiGradeLevel = 'Elementary';
    } else if (gradeLevel == 'Middle School') {
      apiGradeLevel = 'Middle School';
    }
    
    final params = <String, String>{
      'post_season': '0',
      'grade_level': apiGradeLevel,
    };
    
    final url = 'https://www.robotevents.com/api/seasons/$effectiveSeasonId/skills';
    
    print('🌍 Loading world skills rankings for $apiGradeLevel (from $gradeLevel)');
    
    try {
      final response = await http.get(
        Uri.parse(url).replace(queryParameters: params),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        print('✅ Loaded ${data.length} world skills rankings for $apiGradeLevel');
        return data;
      } else {
        print('❌ Error loading skills rankings: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading skills rankings: $e');
      return [];
    }
  }
  
  // Get CSV download URL for skills rankings
  static String getSkillsCsvDownloadUrl({
    int? seasonId,
    bool includePostSeason = false,
    String? gradeLevel,
  }) {
    final effectiveSeasonId = seasonId ?? ApiConfig.currentVexIQSeasonId;
    final params = <String, String>{};
    
    if (includePostSeason) {
      params['post_season'] = '1';
    }
    
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      params['grade_level'] = gradeLevel;
    }
    
    final queryString = params.isNotEmpty 
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    
    return '${ApiConfig.robotEventsBaseUrl}/seasons/$effectiveSeasonId/skills$queryString';
  }
  
  // Download skills data as CSV content
  static Future<String> downloadSkillsCsv({
    int? seasonId,
    bool includePostSeason = false,
    String? gradeLevel,
  }) async {
    final effectiveSeasonId = seasonId ?? ApiConfig.currentVexIQSeasonId;
    final params = <String, String>{};
    
    if (includePostSeason) {
      params['post_season'] = '1';
    } else {
      params['post_season'] = '0';
    }
    
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      params['grade_level'] = gradeLevel;
    }
    
    final url = 'https://www.robotevents.com/api/seasons/$effectiveSeasonId/skills';
    
    try {
      final response = await http.get(
        Uri.parse(url).replace(queryParameters: params),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        
        // Convert JSON to CSV
        if (data.isEmpty) {
          return 'No data available';
        }
        
        final csvBuffer = StringBuffer();
        
        // CSV Header
        csvBuffer.writeln('Rank,Team Number,Team Name,Organization,Score,Programming Skills,Driver Skills,Max Programming,Max Driver');
        
        // CSV Data
        for (final item in data) {
          final team = item['team'] as Map<String, dynamic>?;
          final scores = item['scores'] as Map<String, dynamic>?;
          
          final rank = item['rank']?.toString() ?? '';
          final score = scores?['score']?.toString() ?? '0';
          final programming = scores?['programming']?.toString() ?? '0';
          final driver = scores?['driver']?.toString() ?? '0';
          final maxProgramming = scores?['maxProgramming']?.toString() ?? '0';
          final maxDriver = scores?['maxDriver']?.toString() ?? '0';
          
          final teamNumber = team?['team']?.toString() ?? '';
          final teamName = team?['teamName']?.toString() ?? '';
          final organization = team?['organization']?.toString() ?? '';
          
          // Escape CSV fields that contain commas or quotes
          final escapedTeamName = teamName.contains(',') || teamName.contains('"') ? '"$teamName"' : teamName;
          final escapedOrganization = organization.contains(',') || organization.contains('"') ? '"$organization"' : organization;
          
          csvBuffer.writeln('$rank,$teamNumber,$escapedTeamName,$escapedOrganization,$score,$programming,$driver,$maxProgramming,$maxDriver');
        }
        
        return csvBuffer.toString();
      } else {
        throw Exception('Failed to download data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading CSV: $e');
    }
  }
  
  // Search events (updated to use scraping approach as primary method)
  static Future<List<Event>> searchEvents({
    String? query,
    int? seasonId,
    int? levelClass,
    List<String>? levels,
    int page = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    print('=== Event Search Debug ===');
    print('Query: $query');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    print('Level Class: $levelClass');
    print('Page: $page');
    
    final apiLevels = levels != null && levels.isNotEmpty
        ? ApiConfig.mapDisplayLevelsToApi(levels)
        : levels;

    // If we have a search query, use the enhanced scraping method
    if (query != null && query.trim().isNotEmpty) {
      return await searchEventsWithScraping(
        query: query,
        seasonId: seasonId,
        levelClass: levelClass,
        levels: apiLevels,
        page: page,
        fromDate: fromDate,
        toDate: toDate,
      );
    }
    
    // For empty queries, use regular API search
    final params = ApiConfig.getEventSearchParams(
      query: query,
      seasonId: seasonId,
      levelClass: levelClass,
      levels: apiLevels,
      page: page,
    );
    
    final data = await roboteventsRequest(
      requestUrl: '/events',
      params: params,
    );
    
    final events = <Event>[];
    for (final eventData in data) {
      try {
        events.add(Event.fromJson(eventData));
      } catch (e) {
        print('Error parsing event: $e');
      }
    }
    
    print('Found ${events.length} events');
    return events;
  }
  
  // Web scraping function adapted from Swift RoboScout app
  // Credit: VRC RoboScout by William Castro - used with permission
  static Future<List<String>> roboteventsCompetitionScraper({
    Map<String, dynamic>? params,
  }) async {
    print('=== Event SKU Scraper Debug ===');
    print('Input params: $params');
    
    // Always use VEX IQ competition type for this app
    const competitionType = 'vex-iq-competition';
    var requestUrl = 'https://www.robotevents.com/robot-competitions/$competitionType';
    
    // Base parameters that ensure global results (matching user's working URL)
    var scrapingParams = <String, String>{
      'country_id': '*',  // Critical: Override IP-based region filtering
      'eventType': '',
      'grade_level_id': '',
      'level_class_id': '',
      'from_date': '1970-01-01',  // Fixed date format
      'to_date': '',
      'event_region': '',
      'city': '',
      'distance': '30',
    };
    
    // Add provided params, converting to strings and handling special cases
    if (params != null) {
      params.forEach((key, value) {
        if (value == null) return;
        
        if (key == 'from_date' && value != null) {
          // Use the provided from_date or default to 1970
          scrapingParams[key] = value.toString();
        } else if (key == 'to_date' && value != null) {
          // Use the provided to_date
          scrapingParams[key] = value.toString();
        } else if (key == 'grade_level_id' && value != null) {
          // For VEX IQ, skip grade level restrictions to get both MS and ES
          // This helps find more events
          // Skip this parameter
        } else if (key == 'country_id') {
          // Always force global search regardless of input
          scrapingParams[key] = '*';
        } else if (key == 'seasonId') {
          // Map seasonId to the correct parameter name
          scrapingParams[key] = value.toString();
        } else if (key == 'name') {
          // Search term
          scrapingParams[key] = value.toString();
        } else if (key == 'page') {
          // Page number - don't add to scraping URL, only used for API calls
          // Skip this parameter
        } else {
          // Add other parameters as strings
          scrapingParams[key] = value.toString();
        }
      });
    }
    
    print('Scraping params: $scrapingParams');
    
    // Build URL with all parameters
    var queryParams = <String>[];
    scrapingParams.forEach((key, value) {
      queryParams.add('$key=${Uri.encodeQueryComponent(value)}');
    });
    
    final fullUrl = '$requestUrl?${queryParams.join('&')}';
    print('Scraping URL: $fullUrl');
    
    try {
      // Add randomized delay to appear more human-like and avoid rate limiting
      final randomDelay = 800 + (DateTime.now().millisecond % 1200); // 800-2000ms
      await Future.delayed(Duration(milliseconds: randomDelay));
      
      // Step 1: Get session cookies by visiting the main page first (if network allows)
      String? cookies;
      try {
        print('🍪 Establishing session with main page...');
        final mainPageResponse = await http.get(
          Uri.parse('https://www.robotevents.com/robot-competitions/vex-iq-competition'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Cache-Control': 'max-age=0',
          },
        ).timeout(const Duration(seconds: 15));
        
        // Extract cookies from the main page response
        if (mainPageResponse.headers.containsKey('set-cookie')) {
          cookies = mainPageResponse.headers['set-cookie'];
          print('🍪 Got session cookies: ${cookies?.substring(0, 50)}...');
        }
        
        // Small delay between requests
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('⚠️  Session setup failed (will proceed without cookies): $e');
      }
      
      // Step 2: Advanced Cloudflare bypass with realistic mobile browser fingerprinting
      final mobileUserAgents = [
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
        'Mozilla/5.0 (Linux; Android 14; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
        'Mozilla/5.0 (iPad; CPU OS 17_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
      ];
      final randomUA = mobileUserAgents[DateTime.now().millisecond % mobileUserAgents.length];
      
      final searchHeaders = <String, String>{
        'User-Agent': randomUA,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate', 
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0',
        'Pragma': 'no-cache',
        'DNT': '1',
        'Referer': 'https://www.robotevents.com/robot-competitions/vex-iq-competition',
        'sec-ch-ua-mobile': '?1',
        'Viewport-Width': '390',
        'sec-ch-viewport-width': '390',
      };
      
      // Add session cookies if available
      if (cookies != null) {
        searchHeaders['Cookie'] = cookies;
        print('🍪 Using session cookies for search request');
      }
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: searchHeaders,
      ).timeout(const Duration(seconds: 25));
      
              if (response.statusCode == 200) {
        print('✅ Web scraping successful, extracting SKUs...');
        
        final html = response.body;
        final skus = <String>[];
        
        // Enhanced regex patterns to match RobotEvents SKU structure
        final skuPatterns = [
          r'data-sku="([^"]+)"',  // Primary data attribute pattern
          r'href="[^"]*\/events\/([A-Z0-9-]{10,})"',  // Event URL pattern
          r'\/([A-Z]{2,3}-[A-Z0-9]+-\d{2}-\d{4,6})',  // Standard SKU format pattern
          r'event-([A-Z0-9-]{8,})',  // Event ID patterns
          r'"sku"\s*:\s*"([^"]+)"',  // JSON sku field
        ];
        
        for (final pattern in skuPatterns) {
          final regex = RegExp(pattern, caseSensitive: false);
          final matches = regex.allMatches(html);
          
          for (final match in matches) {
            if (match.group(1) != null) {
              final sku = match.group(1)!.trim();
              // Validate SKU format and avoid duplicates
              if (!skus.contains(sku) && sku.length >= 8 && sku.contains('-')) {
                skus.add(sku);
              }
            }
          }
        }
        
        print('🔍 Extracted ${skus.length} unique SKUs from website: $skus');
        
        // Return the SKUs so the calling function can use them to fetch events
        return skus;
      } else {
        print('❌ Web scraping failed with status: ${response.statusCode}');
        print('Response body: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
        
        // Try alternative approach with mobile-specific URL
        if (response.statusCode == 403 || response.statusCode == 503) {
          print('🔄 Trying mobile URL bypass...');
          final mobileUrl = fullUrl.replaceAll('www.robotevents.com', 'm.robotevents.com');
          
          try {
            final mobileResponse = await http.get(
              Uri.parse(mobileUrl),
              headers: {
                'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.9',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
                'Sec-Fetch-Dest': 'document',
                'Sec-Fetch-Mode': 'navigate',
                'Sec-Fetch-Site': 'same-origin',
                'sec-ch-ua-mobile': '?1',
                'Viewport-Width': '390',
                'Cache-Control': 'max-age=0',
              },
            ).timeout(const Duration(seconds: 20));
            
            if (mobileResponse.statusCode == 200) {
              print('✅ Mobile URL bypass successful!');
              // Process mobile response similar to desktop
              // (implementation would be similar to the desktop version)
            } else {
              print('❌ Mobile URL also failed: ${mobileResponse.statusCode}');
            }
          } catch (e) {
            print('❌ Mobile URL bypass failed: $e');
          }
        }
        
        return [];
      }
    } catch (e) {
      print('Network request failed: $e');
      return [];
    }
  }
  
  // Enhanced event search using two-step process (scrape + API call)
  // Credit: Adapted from VRC RoboScout by William Castro - used with permission
  static Future<List<Event>> searchEventsWithScraping({
    String? query,
    int? seasonId,
    int? levelClass,
    List<String>? levels,
    int page = 1,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    print('=== Enhanced Event Search Debug ===');
    print('Query: $query');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    print('Level Class: $levelClass');
    print('Page: $page');
    
    if (query == null || query.trim().isEmpty) {
      print('No query provided, falling back to regular API search');
      return await _fallbackApiSearch(
        query: query,
        seasonId: seasonId,
        levelClass: levelClass,
        levels: levels,
        page: page,
      );
    }
    
    // Auto-detect season from query
    print('🔍 Starting season auto-detection for query: "$query"');
    var targetSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
    print('🔍 Initial season ID: $targetSeasonId');
    
    // Check for season patterns
    if (query.contains('2024-2025') || query.contains('2024-25') || query.toLowerCase().contains('rapid relay')) {
      targetSeasonId = 189; // Rapid Relay 2024-2025
      print('🔍 Auto-detected 2024-2025 season from query, using season ID: $targetSeasonId');
    } else if (query.contains('2023-2024') || query.contains('2023-24') || query.toLowerCase().contains('full volume')) {
      targetSeasonId = 180; // Full Volume 2023-2024
      print('🔍 Auto-detected 2023-2024 season from query, using season ID: $targetSeasonId');
    } else if (query.contains('2025-2026') || query.contains('2025-26') || query.toLowerCase().contains('mix & match')) {
      targetSeasonId = 196; // Mix & Match 2025-2026
      print('🔍 Auto-detected 2025-2026 season from query, using season ID: $targetSeasonId');
    } else {
      print('🔍 No season pattern detected in query, using default season ID: $targetSeasonId');
    }
    
    // Update seasonId for subsequent searches
    seasonId = targetSeasonId;
    print('🔍 Final season ID to use: $seasonId');
    
    try {
      // Step 1: Try scraping approach
      print('Attempting web scraping approach...');
      
      final scrapingParams = <String, dynamic>{
        'name': query.trim(),
        'seasonId': seasonId ?? ApiConfig.getSelectedSeasonId(),
        'page': page,
      };
      
      print('🔍 Scraping params season ID: ${scrapingParams['seasonId']} (from seasonId: $seasonId)');
      
      // Add level class if specified
      if (levelClass != null && levelClass != 0) {
        scrapingParams['level_class_id'] = levelClass;
      }
      
      // For VEX IQ, don't restrict by grade level to get both MS and ES events
      // scrapingParams['grade_level_id'] = 2;
      
      // Add date range if provided
      if (fromDate != null) {
        scrapingParams['from_date'] = fromDate.toIso8601String().split('T')[0];
      } else {
        scrapingParams['from_date'] = '1970-01-01';
      }
      
      if (toDate != null) {
        scrapingParams['to_date'] = toDate.toIso8601String().split('T')[0];
      }
      
      print('Scraping with params: $scrapingParams');
      
      final skuArray = await roboteventsCompetitionScraper(params: scrapingParams);
      
      if (skuArray.isNotEmpty) {
        print('Found ${skuArray.length} SKUs, fetching event data...');
        
        // Step 2: Get event data using the scraped SKUs
        final seasonParam = seasonId ?? ApiConfig.getSelectedSeasonId();
        final requestUrl = '/seasons/$seasonParam/events';
        final apiParams = <String, dynamic>{
          'sku': skuArray,
          'per_page': 250,
        };
        
        print('Making API call to: $requestUrl');
        print('API params: $apiParams');
        
        final data = await roboteventsRequest(
          requestUrl: requestUrl,
          params: apiParams,
        );
        
        print('API returned ${data.length} events');
        
        final events = <Event>[];
        for (final eventData in data) {
          try {
            events.add(Event.fromJson(eventData));
          } catch (e) {
            print('Error parsing event: $e');
          }
        }
        
        if (events.isNotEmpty) {
          print('Successfully parsed ${events.length} events via scraping');
          print('=== End Enhanced Event Search Debug ===');
          return events;
        }
      }
      
      print('Scraping approach failed or returned no results');
      
      // Step 2: Try alternative scraping with simplified parameters
      print('Trying simplified scraping approach...');
      
      final simplifiedParams = <String, dynamic>{
        'name': query.split(' ').first, // Just use the first word
        'seasonId': seasonId ?? ApiConfig.getSelectedSeasonId(),
      };
      
      print('🔍 Simplified scraping params season ID: ${simplifiedParams['seasonId']} (from seasonId: $seasonId)');
      
      final simplifiedSkus = await roboteventsCompetitionScraper(params: simplifiedParams);
      
      if (simplifiedSkus.isNotEmpty) {
        print('Found ${simplifiedSkus.length} SKUs with simplified search');
        
        final seasonParam = seasonId ?? ApiConfig.getSelectedSeasonId();
        final requestUrl = '/seasons/$seasonParam/events';
        final apiParams = <String, dynamic>{
          'sku': simplifiedSkus,
          'per_page': 250,
        };
        
        final data = await roboteventsRequest(
          requestUrl: requestUrl,
          params: apiParams,
        );
    
    final events = <Event>[];
    for (final eventData in data) {
      try {
        final event = Event.fromJson(eventData);
            // Filter events by query relevance
            if (_isEventRelevant(event, query)) {
        events.add(event);
            }
      } catch (e) {
            print('Error parsing event: $e');
      }
    }
    
        if (events.isNotEmpty) {
          print('Successfully found ${events.length} relevant events via simplified scraping');
    return events;
        }
      }
      
      print('All scraping approaches failed, falling back to API search...');
      
    } catch (e) {
      print('Error in enhanced event search: $e');
      print('Falling back to regular search...');
    }
    
    // Step 3: Fallback to enhanced API search with multiple strategies
    return await _enhancedFallbackSearch(
      query: query,
      seasonId: seasonId,
      levelClass: levelClass,
      levels: levels,
      page: page,
    );
  }
  
  // Check if a query is location-based
  static bool _isLocationQuery(String queryLower) {
    final locationWords = ['panama', 'singapore', 'malaysia', 'california', 'texas', 'florida', 'canada', 'australia', 'new zealand', 'china', 'thailand', 'taiwan', 'macau', 'hong kong', 'japan', 'korea', 'mexico', 'brazil', 'argentina', 'chile', 'india', 'philippines', 'vietnam', 'indonesia'];
    return locationWords.any((location) => queryLower.contains(location));
  }
  
  // Check if an event is relevant to the search query
  static bool _isEventRelevant(Event event, String query) {
    final queryLower = query.toLowerCase();
    final eventName = event.name.toLowerCase();
    final eventLocation = '${event.city} ${event.region} ${event.country}'.toLowerCase();
    final eventSku = event.sku.toLowerCase();
    
    // Silent relevance check to reduce log noise
    
    // For location-based searches, be very inclusive
    final isLocationSearch = _isLocationQuery(queryLower);
    
    // Check for direct/exact matches first
    if (eventName.contains(queryLower) || 
        eventLocation.contains(queryLower) || 
        eventSku.contains(queryLower)) {
      return true;
    }
    
    // Check location components individually for location searches
    if (isLocationSearch) {
      final city = event.city.toLowerCase();
      final region = event.region.toLowerCase();
      final country = event.country.toLowerCase();
      
      // Checking location components
      
      if (city.contains(queryLower) || 
          region.contains(queryLower) || 
          country.contains(queryLower)) {
        return true;
      }
    }
    
    // Word-based matching - Split query into words and check matches
    final queryWords = queryLower.split(RegExp(r'\s+'))
        .where((word) => word.length >= 2)  // Minimum 2 characters
        .toList();
    
    final matchedWords = <String>[];
    
    for (final word in queryWords) {
      bool wordFound = false;
      
      if (eventName.contains(word)) {
        matchedWords.add(word);
        wordFound = true;
        // Word found in event name
      }
      
      if (eventLocation.contains(word)) {
        if (!wordFound) matchedWords.add(word);
        wordFound = true;
        // Word found in event location
      }
      
      if (eventSku.contains(word)) {
        if (!wordFound) matchedWords.add(word);
        wordFound = true;
        // Word found in event SKU
      }
    }
    
    // Query analysis completed
    
    // For location searches, be very lenient - require at least 1 match
    if (isLocationSearch && matchedWords.isNotEmpty) {
      return true;
    }
    
    // For regular searches, require at least 1 match for short queries
    if (queryWords.length <= 2 && matchedWords.isNotEmpty) {
      return true;
    }
    
    // For longer queries, require at least 2 matches or 50% of words
    if (queryWords.length > 2) {
      final requiredMatches = math.max(1, (queryWords.length * 0.5).ceil());
      if (matchedWords.length >= requiredMatches) {
        return true;
      }
    }
    
    return false;
  }
  
  // Enhanced fallback search with multiple API strategies
  static Future<List<Event>> _enhancedFallbackSearch({
    String? query,
    int? seasonId,
    int? levelClass,
    List<String>? levels,
    int page = 1,
  }) async {
    print('=== Enhanced Fallback Search ===');
    print('🔍 Enhanced fallback search called with:');
    print('   Query: "$query"');
    print('   Season ID: $seasonId');
    print('   Level Class: $levelClass');
    print('   Page: $page');
    
    // Global API request counter across all strategies
    int globalApiRequests = 0;
    int globalEventsProcessed = 0;
    
    if (query == null || query.trim().isEmpty) {
      print('No query provided, falling back to regular API search');
      return await _fallbackApiSearch(
        query: query,
        seasonId: seasonId,
        levelClass: levelClass,
        levels: levels,
        page: page,
      );
    }
    
    final allEvents = <Event>[];
    final seenEventIds = <int>{};
    final selectedSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
    final isLocationSearch = _isLocationQuery(query.toLowerCase());
    
    print('🔍 Location search detected: $isLocationSearch');
    print('🔍 Using season ID: $selectedSeasonId');
    
    // Strategy 1: Search with query parameter
    print('🔍 Strategy 1: API search with query parameter');
    try {
      final params1 = ApiConfig.getEventSearchParams(
        query: query,
        seasonId: selectedSeasonId,
        levelClass: levelClass,
        levels: levels,
        page: 1,
      );
      print('🔍 Strategy 1 URL: ${ApiConfig.robotEventsBaseUrl}/events?${_buildQueryString(params1)}');
      
      final eventsData1 = await roboteventsRequest(
        requestUrl: '/events',
        params: params1,
      );
      
      globalApiRequests++;
      globalEventsProcessed += eventsData1.length;
      
      print('🔍 Strategy 1 returned ${eventsData1.length} events (📊 Global API requests: $globalApiRequests, Global events: $globalEventsProcessed)');
      if (eventsData1.isNotEmpty) {
        final firstEvent = Event.fromJson(eventsData1[0]);
        final lastEvent = Event.fromJson(eventsData1[eventsData1.length-1]);
        print('🔍 Strategy 1 first event: "${firstEvent.name}" (${firstEvent.city}, ${firstEvent.region}, ${firstEvent.country})');
        print('🔍 Strategy 1 last event: "${lastEvent.name}" (${lastEvent.city}, ${lastEvent.region}, ${lastEvent.country})');
      }
      
      for (final eventData in eventsData1) {
        final event = Event.fromJson(eventData);
        if (!seenEventIds.contains(event.id) && _isEventRelevant(event, query)) {
          allEvents.add(event);
          seenEventIds.add(event.id);
          print('✅ Strategy 1 added: "${event.name}" (${event.city}, ${event.region}, ${event.country})');
        }
      }
    } catch (e) {
      print('❌ Strategy 1 failed: $e');
    }
    
    // Strategy 2: COMPREHENSIVE search with client-side filtering (ALL pages)
    print('🔍 Strategy 2: COMPREHENSIVE search with client-side filtering');
    
    int totalApiRequests = 0;
    int totalEventsFound = 0;
    int totalRelevantEvents = 0;
    
    for (int pageNum = 1; ; pageNum++) {
      try {
        final params2 = ApiConfig.getEventSearchParams(
          seasonId: selectedSeasonId,
          levelClass: levelClass,
          levels: levels,
          page: pageNum,
        );
        print('🔍 Strategy 2 Page $pageNum URL: ${ApiConfig.robotEventsBaseUrl}/events?${_buildQueryString(params2)}');
        
        final eventsData2 = await roboteventsRequest(
          requestUrl: '/events',
          params: params2,
        );
        
        totalApiRequests++;
        totalEventsFound += eventsData2.length;
        globalApiRequests++;
        globalEventsProcessed += eventsData2.length;
        
        print('🔍 Strategy 2 Page $pageNum returned ${eventsData2.length} events (📊 S2 API requests: $totalApiRequests, S2 events: $totalEventsFound, 🌐 Global API requests: $globalApiRequests, Global events: $globalEventsProcessed)');
        
        // If no events returned, we've reached the end
        if (eventsData2.isEmpty) {
          print('🔍 Strategy 2 Page $pageNum returned no events, stopping pagination');
          break;
        }
        
        if (eventsData2.isNotEmpty) {
          final firstEvent = Event.fromJson(eventsData2[0]);
          final lastEvent = Event.fromJson(eventsData2[eventsData2.length-1]);
          print('🔍 Strategy 2 Page $pageNum first event: "${firstEvent.name}" (${firstEvent.city}, ${firstEvent.region}, ${firstEvent.country})');
          print('🔍 Strategy 2 Page $pageNum last event: "${lastEvent.name}" (${lastEvent.city}, ${lastEvent.region}, ${lastEvent.country})');
        }
        
        var pageRelevantCount = 0;
        for (final eventData in eventsData2) {
          final event = Event.fromJson(eventData);
          if (!seenEventIds.contains(event.id) && _isEventRelevant(event, query)) {
            allEvents.add(event);
            seenEventIds.add(event.id);
            pageRelevantCount++;
            totalRelevantEvents++;
            print('✅ Strategy 2 Page $pageNum added: "${event.name}" (${event.city}, ${event.region}, ${event.country})');
          }
        }
        print('🔍 Strategy 2 Page $pageNum found $pageRelevantCount relevant events (📊 Total relevant: $totalRelevantEvents)');
        
        // If we found fewer than 250 events, we've reached the end
        if (eventsData2.length < 250) {
          print('🔍 Strategy 2 reached end of results at page $pageNum');
          break;
        }
        
        // Safety limit to prevent runaway API usage
        if (pageNum >= 50) {
          print('⚠️ Strategy 2 hit safety limit of 50 pages, stopping');
          break;
        }
        
      } catch (e) {
        print('❌ Strategy 2 Page $pageNum failed: $e');
        break;
      }
    }
    
    print('📊 Strategy 2 COMPREHENSIVE SEARCH STATS:');
    print('   🔢 Total API requests: $totalApiRequests');
    print('   📋 Total events processed: $totalEventsFound');
    print('   ✅ Total relevant events found: $totalRelevantEvents');
    print('   📊 Average events per page: ${totalEventsFound / (totalApiRequests > 0 ? totalApiRequests : 1)}');
    print('   🎯 Relevance rate: ${totalRelevantEvents / (totalEventsFound > 0 ? totalEventsFound : 1) * 100}%');
    
    // Strategy 3: Search with individual words  
    print('🔍 Strategy 3: Search with individual words');
    final queryWords = query.toLowerCase().split(RegExp(r'\s+'))
        .where((word) => word.length >= 2)
        .toList();
    
    print('🔍 Strategy 3 words to search: $queryWords');
    
    for (final word in queryWords) {
      try {
        final params3 = ApiConfig.getEventSearchParams(
          query: word,
          seasonId: selectedSeasonId,
          levelClass: levelClass,
          levels: levels,
          page: 1,
        );
        print('🔍 Strategy 3 word "$word" URL: ${ApiConfig.robotEventsBaseUrl}/events?${_buildQueryString(params3)}');
        
        final eventsData3 = await roboteventsRequest(
          requestUrl: '/events',
          params: params3,
        );
        
        globalApiRequests++;
        globalEventsProcessed += eventsData3.length;
        
        print('🔍 Strategy 3 for word "$word" returned ${eventsData3.length} events (📊 Global API requests: $globalApiRequests, Global events: $globalEventsProcessed)');
        if (eventsData3.isNotEmpty) {
          final firstEvent = Event.fromJson(eventsData3[0]);
          print('🔍 Strategy 3 "$word" first event: "${firstEvent.name}" (${firstEvent.city}, ${firstEvent.region}, ${firstEvent.country})');
        }
        
        var wordRelevantCount = 0;
        for (final eventData in eventsData3) {
          final event = Event.fromJson(eventData);
          if (!seenEventIds.contains(event.id) && _isEventRelevant(event, query)) {
            allEvents.add(event);
            seenEventIds.add(event.id);
            wordRelevantCount++;
            print('✅ Strategy 3 "$word" added: "${event.name}" (${event.city}, ${event.region}, ${event.country})');
          }
        }
        print('🔍 Strategy 3 for word "$word" found $wordRelevantCount relevant events');
      } catch (e) {
        print('❌ Strategy 3 for word "$word" failed: $e');
      }
    }
    
    print('🔍 Enhanced fallback found ${allEvents.length} relevant events total');
    
    // COMPREHENSIVE FINAL STATISTICS
    print('');
    print('==================== 📊 COMPREHENSIVE SEARCH STATISTICS ====================');
    print('🔢 TOTAL API REQUESTS MADE: $globalApiRequests');
    print('📋 TOTAL EVENTS PROCESSED: $globalEventsProcessed');
    print('✅ TOTAL RELEVANT EVENTS FOUND: ${allEvents.length}');
    print('📊 AVERAGE EVENTS PER API REQUEST: ${globalEventsProcessed / (globalApiRequests > 0 ? globalApiRequests : 1)}');
    print('🎯 OVERALL RELEVANCE RATE: ${allEvents.length / (globalEventsProcessed > 0 ? globalEventsProcessed : 1) * 100}%');
    print('🏆 SEARCH EFFICIENCY: ${allEvents.length} relevant events from $globalApiRequests API calls');
    print('=======================================================================');
    print('');
    
    print('🔍 Final URLs checked:');
    print('   - Strategy 1 (with query): ${ApiConfig.robotEventsBaseUrl}/events?program=41&season=$selectedSeasonId&name=$query&page=1&per_page=250');
    print('   - Strategy 2 (broad): ${ApiConfig.robotEventsBaseUrl}/events?program=41&season=$selectedSeasonId&page=1&per_page=250');
    print('   - Strategy 3 (word search): ${ApiConfig.robotEventsBaseUrl}/events?program=41&season=$selectedSeasonId&name=panama&page=1&per_page=250');
    
    if (allEvents.isNotEmpty) {
      print('🔍 Final events found:');
      for (int i = 0; i < allEvents.length && i < 5; i++) {
        final event = allEvents[i];
        print('   ${i+1}. "${event.name}" (${event.city}, ${event.region}, ${event.country}) [ID: ${event.id}]');
      }
    } else {
      print('❌ No relevant events found for query "$query" in season $selectedSeasonId');
    }
    
    // Sort events by date (most recent first), handling null dates
    allEvents.sort((a, b) {
      if (a.start == null && b.start == null) return 0;
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return b.start!.compareTo(a.start!);
    });
    
    return allEvents;
  }
  
  // Fetch events by SKU array (much more efficient than individual scraping)
  static Future<List<Event>> _fetchEventsBySKUs(List<String> skus, {int? seasonId}) async {
    print('📡 Fetching events for ${skus.length} SKUs via API...');
    
    try {
      // Use the SKU array parameter to fetch multiple events at once
      final params = {
        'sku': skus, // Pass as array
        'per_page': 250,
      };
      
      // Add season filter if provided
      if (seasonId != null) {
        params['season'] = seasonId;
      }
      
      print('📡 SKU API request with params: $params');
      
      final data = await roboteventsRequest(
        requestUrl: '/events',
        params: params,
      );
      
      final events = <Event>[];
      for (final eventData in data) {
        try {
          final event = Event.fromJson(eventData);
          events.add(event);
          print('✅ SKU API loaded event: "${event.name}" [${event.sku}]');
        } catch (e) {
          print('❌ Error parsing event from SKU API: $e');
        }
      }
      
      print('📡 SKU API successfully fetched ${events.length} events');
      return events;
      
    } catch (e) {
      print('❌ SKU API request failed: $e');
      return [];
    }
  }

  // Helper function to build query string for debugging
  static String _buildQueryString(Map<String, dynamic> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }
  
  // Helper method to get month name for date formatting
  static String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
  
  // Get comprehensive team data (combines all data sources)
  static Future<Map<String, dynamic>> getComprehensiveTeamData({
    required Team team,
    int? seasonId,
  }) async {
    print('=== Getting Comprehensive Team Data for ${team.number} ===');
    
    final targetSeasonId = seasonId ?? ApiConfig.getSelectedSeasonId();
    
    // Fetch all data sources in parallel for efficiency
    final futures = await Future.wait([
      getTeamEvents(teamId: team.id, seasonId: targetSeasonId),
      getTeamAwards(teamId: team.id, seasonId: targetSeasonId),
      getTeamRankings(teamId: team.id, seasonId: targetSeasonId),
      getTeamWorldSkills(teamId: team.id, seasonId: targetSeasonId),
    ]);
    
    final events = futures[0] as List<Event>;
    final awards = futures[1] as List<dynamic>;
    final rankings = futures[2] as List<dynamic>;
    final worldSkills = futures[3] as List<dynamic>;
    
    print('Fetched: ${events.length} events, ${awards.length} awards, ${rankings.length} rankings, ${worldSkills.length} world skills');
    print('=== End Comprehensive Team Data ===');
    
    return {
      'events': events,
      'awards': awards,
      'rankings': rankings,
      'worldSkills': worldSkills,
      'seasonId': targetSeasonId,
    };
  }
  
  // Get available seasons for VEX IQ
  static List<Map<String, dynamic>> getAvailableSeasons() {
    final vexiqSeasons = ApiConfig.seasonIdMap[2] ?? {};
    final seasons = <Map<String, dynamic>>[];
    
    // Sort seasons by ID descending (newest first)
    final sortedSeasonIds = vexiqSeasons.keys.toList()..sort((a, b) => b.compareTo(a));
    
    for (final seasonId in sortedSeasonIds) {
      final seasonName = vexiqSeasons[seasonId]!;
      seasons.add({
        'id': seasonId,
        'name': seasonName,
        'displayName': ApiConfig.getSeasonDisplayName(seasonId),
      });
    }
    
    return seasons;
  }
  
  // Get teams registered for an event with pagination support
  static Future<List<Team>> getEventTeams({
    required int eventId,
    int page = 1,
  }) async {
    print('=== Event Teams Debug ===');
    print('Event ID: $eventId');
    
    List<dynamic> allTeamsData = [];
    int currentPage = 1;
    bool hasMorePages = true;
    
    while (hasMorePages) {
      final params = {
        'event': eventId,
        'page': currentPage,
        'per_page': ApiConfig.defaultPageSize,
      };
      
      final data = await roboteventsRequest(
        requestUrl: '/teams',
        params: params,
      );
      
      print('Page $currentPage: Event Teams API returned ${data.length} teams');
      
      allTeamsData.addAll(data);
      
      // Check if we've reached the end (less than max page size means no more pages)
      if (data.length < ApiConfig.defaultPageSize) {
        hasMorePages = false;
      } else {
        currentPage++;
      }
    }
    
    print('Total Event Teams API returned ${allTeamsData.length} teams');
    
    final teams = <Team>[];
    for (final teamData in allTeamsData) {
      try {
        final team = Team.fromJson(teamData);
        teams.add(team);
      } catch (e) {
        print('Error parsing team data: $e');
      }
    }
    
    print('Total teams parsed: ${teams.length}');
    print('=== End Event Teams Debug ===');
    
    return teams;
  }
  
  // Get team matches directly (Bug Patch 3 requirement)
  static Future<List<dynamic>> getTeamMatches({
    required int teamId,
    List<int>? eventIds,
    int? seasonId,
  }) async {
    print('=== Team Matches Debug ===');
    print('Team ID: $teamId');
    print('Event IDs: $eventIds');
    print('Season ID: ${seasonId ?? ApiConfig.getSelectedSeasonId()}');
    
    final params = <String, dynamic>{};
    if (seasonId != null) {
      params['season'] = seasonId;
    }
    
    // Build the URL manually to handle array parameters correctly
    String url = '${ApiConfig.robotEventsBaseUrl}/teams/$teamId/matches';
    final queryParts = <String>[];
    
    // Add season parameter
    if (seasonId != null) {
      queryParts.add('season=$seasonId');
    }
    
    // Add event array parameters
    if (eventIds != null && eventIds.isNotEmpty) {
      for (final eventId in eventIds) {
        queryParts.add('event[]=$eventId');
      }
    }
    
    if (queryParts.isNotEmpty) {
      url += '?${queryParts.join('&')}';
    }
    
    print('🔍 Team Matches URL: $url');
    
    // Use direct HTTP request for array parameters
    final response = await http.get(
      Uri.parse(url),
      headers: ApiConfig.robotEventsHeaders,
    );
    
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final data = jsonData['data'] as List<dynamic>? ?? [];
      print('Team Matches API returned ${data.length} matches');
      print('=== End Team Matches Debug ===');
      return data;
    } else {
      print('Team Matches API error: ${response.statusCode} - ${response.body}');
      print('=== End Team Matches Debug ===');
      throw Exception('API error: ${response.statusCode}');
    }
  }

  // Get matches for an event division with pagination support
  static Future<List<dynamic>> getEventMatches({
    required int eventId,
    required int divisionId,
    int page = 1,
  }) async {
    print('=== Event Matches Debug ===');
    print('Event ID: $eventId, Division ID: $divisionId');
    
    List<dynamic> allMatches = [];
    int currentPage = 1;
    bool hasMorePages = true;
    
    while (hasMorePages) {
      final params = {
        'page': currentPage,
        'per_page': ApiConfig.defaultPageSize,
      };
      
      try {
        // Try division-specific matches first (VRC RoboScout pattern)
        final data = await roboteventsRequest(
          requestUrl: '/events/$eventId/divisions/$divisionId/matches',
          params: params,
        );
        
        print('Page $currentPage: Event Matches API returned ${data.length} matches for division $divisionId');
        
        // Process and validate match data
        for (final match in data) {
          // Ensure all required fields are present
          final processedMatch = _processMatchData(match);
          allMatches.add(processedMatch);
        }
        
        // Check if we've reached the end (less than max page size means no more pages)
        if (data.length < ApiConfig.defaultPageSize) {
          hasMorePages = false;
        } else {
          currentPage++;
        }
        
      } catch (e) {
        print('Division-specific matches failed: $e');
        
        // Fallback: Try direct event matches for events without proper divisions
        try {
          print('🔄 Trying fallback: direct event matches endpoint...');
          final fallbackData = await roboteventsRequest(
            requestUrl: '/events/$eventId/matches',
            params: params,
          );
          
          print('Page $currentPage: ✅ Fallback Event Matches API returned ${fallbackData.length} matches');
          
          // Process and validate match data
          for (final match in fallbackData) {
            final processedMatch = _processMatchData(match);
            allMatches.add(processedMatch);
          }
          
          // Check if we've reached the end
          if (fallbackData.length < ApiConfig.defaultPageSize) {
            hasMorePages = false;
          } else {
            currentPage++;
          }
          
        } catch (fallbackError) {
          print('❌ Fallback matches API also failed: $fallbackError');
          hasMorePages = false;
        }
      }
    }
    
    // Sort matches like VRC RoboScout: by instance first, then by round, then by match number
    allMatches.sort((a, b) {
      // First sort by instance (match number)
      final aInstance = a['instance'] ?? 0;
      final bInstance = b['instance'] ?? 0;
      if (aInstance != bInstance) {
        return aInstance.compareTo(bInstance);
      }
      
      // Then sort by round order
      final aRound = a['round'] ?? 0;
      final bRound = b['round'] ?? 0;
      if (aRound != bRound) {
        return aRound.compareTo(bRound);
      }
      
      // Finally sort by match number (matchnum) to handle any swaps
      final aMatchNum = a['matchnum'] ?? 0;
      final bMatchNum = b['matchnum'] ?? 0;
      return aMatchNum.compareTo(bMatchNum);
    });
    
    print('Total Event Matches API returned ${allMatches.length} matches for division $divisionId');
    print('=== End Event Matches Debug ===');
    
    return allMatches;
  }

  // Process and validate match data (VRC RoboScout pattern)
  static Map<String, dynamic> _processMatchData(Map<String, dynamic> match) {
    final processed = Map<String, dynamic>.from(match);
    
    // Ensure all required fields are present with proper defaults
    processed['id'] = processed['id'] ?? 0;
    processed['name'] = processed['name'] ?? 'Unknown Match';
    processed['field'] = processed['field'] ?? '';
    processed['round'] = processed['round'] ?? 0;
    processed['instance'] = processed['instance'] ?? 0;
    processed['matchnum'] = processed['matchnum'] ?? 0;
    
    // Ensure instance and matchnum are properly set
    // Sometimes the API returns different field names
    if (processed['instance'] == 0 && processed['matchnum'] != 0) {
      processed['instance'] = processed['matchnum'];
    }
    if (processed['matchnum'] == 0 && processed['instance'] != 0) {
      processed['matchnum'] = processed['instance'];
    }
    
    // Process date fields with proper parsing
    processed['scheduled'] = _parseRobotEventsDate(processed['scheduled']);
    processed['started'] = _parseRobotEventsDate(processed['started']);
    processed['finished'] = _parseRobotEventsDate(processed['finished']);
    
    // Ensure alliances structure is correct
    if (processed['alliances'] != null) {
      final alliances = processed['alliances'] as List<dynamic>;
      for (final alliance in alliances) {
        if (alliance is Map<String, dynamic>) {
          // Ensure alliance has required fields
          alliance['color'] = alliance['color'] ?? '';
          alliance['score'] = alliance['score'] ?? -1;
          alliance['teams'] = alliance['teams'] ?? [];
          
          // Process teams in alliance
          final teams = alliance['teams'] as List<dynamic>;
          for (final team in teams) {
            if (team is Map<String, dynamic>) {
              team['team'] = team['team'] ?? {};
              if (team['team'] is Map<String, dynamic>) {
                final teamData = team['team'] as Map<String, dynamic>;
                teamData['id'] = teamData['id'] ?? 0;
                teamData['name'] = teamData['name'] ?? 'Unknown';
              }
            }
          }
        }
      }
    }
    
    return processed;
  }

  // Parse RobotEvents date format (VRC RoboScout pattern)
  static String? _parseRobotEventsDate(dynamic dateValue) {
    if (dateValue == null || dateValue.toString().isEmpty) {
      return null;
    }
    
    final dateString = dateValue.toString();
    
    try {
      // Handle different date formats
      if (dateString.contains('T') && dateString.contains('Z')) {
        // Format: "2023-04-26T11:54:40Z"
        return dateString;
      } else if (dateString.contains('T') && (dateString.contains('+') || dateString.contains('-'))) {
        // Format: "2023-04-26T11:54:40-04:00" or "2023-04-26T11:54:40+04:00"
        return dateString;
      } else if (dateString.contains('T')) {
        // Format: "2023-04-26T11:54:40" - assume UTC
        return '${dateString}Z';
      } else {
        // Unknown format, return as is
        return dateString;
      }
    } catch (e) {
      print('Error parsing date: $dateString - $e');
      return dateString;
    }
  }
  
  // Get skills rankings for an event with pagination support
  static Future<List<dynamic>> getEventSkills({
    required int eventId,
    int page = 1,
  }) async {
    print('=== Event Skills Debug ===');
    print('Event ID: $eventId');
    
    List<dynamic> allSkills = [];
    int currentPage = 1;
    bool hasMorePages = true;
    
    while (hasMorePages) {
      final params = {
        'page': currentPage,
        'per_page': ApiConfig.defaultPageSize,
      };
      
      try {
        print('🔍 Trying skills endpoint: /events/$eventId/skills (page $currentPage)');
        final data = await roboteventsRequest(
          requestUrl: '/events/$eventId/skills',
          params: params,
        );
        
        print('Page $currentPage: Event Skills API returned ${data.length} skills records');
        
        allSkills.addAll(data);
        
        // Check if we've reached the end (less than max page size means no more pages)
        if (data.length < ApiConfig.defaultPageSize) {
          hasMorePages = false;
        } else {
          currentPage++;
        }
        
      } catch (e) {
        print('❌ Skills API failed: $e');
        hasMorePages = false;
      }
    }
    
    print('Total Event Skills API returned ${allSkills.length} skills records');
    if (allSkills.isNotEmpty) {
      print('  Sample skill types found: ${allSkills.map((s) => s['type']).toSet().toList()}');
    }
    print('=== End Event Skills Debug ===');
    
    return allSkills;
  }

  // Get awards for an event with pagination support
  static Future<List<dynamic>> getEventAwards({
    required int eventId,
    int page = 1,
  }) async {
    print('=== Event Awards Debug ===');
    print('Event ID: $eventId');
    
    List<dynamic> allAwards = [];
    int currentPage = 1;
    bool hasMorePages = true;
    
    while (hasMorePages) {
      final params = {
        'page': currentPage,
        'per_page': ApiConfig.defaultPageSize,
      };
      
      try {
        print('🔍 Trying awards endpoint: /events/$eventId/awards (page $currentPage)');
        final data = await roboteventsRequest(
          requestUrl: '/events/$eventId/awards',
          params: params,
        );
        
        print('Page $currentPage: Event Awards API returned ${data.length} awards records');
        
        allAwards.addAll(data);
        
        // Check if we've reached the end (less than max page size means no more pages)
        if (data.length < ApiConfig.defaultPageSize) {
          hasMorePages = false;
        } else {
          currentPage++;
        }
        
      } catch (e) {
        print('❌ Awards API failed: $e');
        hasMorePages = false;
      }
    }
    
    print('Total Event Awards API returned ${allAwards.length} awards records');
    if (allAwards.isNotEmpty) {
      print('  Sample award types found: ${allAwards.map((a) => a['title']).toSet().toList()}');
    }
    print('=== End Event Awards Debug ===');
    
    return allAwards;
  }

  // Get event details including divisions (like VRC RoboScout)
  static Future<Map<String, dynamic>> getEventDetails({
    required int eventId,
  }) async {
    print('=== Event Details Debug ===');
    print('Event ID: $eventId');
    
    try {
      final response = await roboteventsRequest(
        requestUrl: '/events/$eventId',
        params: {},
      );
      
      // The response should be a single event object
      final eventData = response.isNotEmpty ? response[0] : {};
      
      // Debug: Print the full event data structure to understand divisions
      print('🔍 Full event data keys: ${eventData.keys.toList()}');
      if (eventData.containsKey('divisions')) {
        print('🔍 Divisions field type: ${eventData['divisions'].runtimeType}');
        print('🔍 Divisions field value: ${eventData['divisions']}');
      }
      
      // Extract divisions from event data (like VRC RoboScout)
      dynamic divisionsData = eventData['divisions'];
      
      // If divisions is null, try alternative approaches
      if (divisionsData == null) {
        print('🔍 Divisions field is null, checking for alternative structures...');
        
        // Some events might have divisions in a different structure
        if (eventData.containsKey('division')) {
          divisionsData = [eventData['division']];
          print('🔍 Found single division in "division" field');
        } else {
          print('🔍 No divisions found in event data, trying to fetch divisions separately...');
          
          // Try to fetch divisions from a separate endpoint
          try {
            final divisionsResponse = await roboteventsRequest(
              requestUrl: '/events/$eventId/divisions',
              params: {},
            );
            
            if (divisionsResponse.isNotEmpty) {
              divisionsData = divisionsResponse;
              print('🔍 Found ${divisionsResponse.length} divisions from separate endpoint');
            } else {
              print('🔍 No divisions found in separate endpoint, trying alternative approaches...');
              
              // For VEX IQ, try to get divisions from rankings data (where they actually exist)
              try {
                print('🔍 Trying to extract divisions from rankings data...');
                
                // Try multiple division IDs to find all divisions (World Championships have multiple divisions)
                final Set<Map<String, dynamic>> uniqueDivisions = {};
                final List<int> divisionIdsToTry = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]; // Try common division IDs
                
                for (final divisionId in divisionIdsToTry) {
                  try {
                    print('🔍 Checking division ID: $divisionId');
                    final rankingsResponse = await roboteventsRequest(
                      requestUrl: '/events/$eventId/divisions/$divisionId/rankings',
                      params: {'per_page': 1}, // Just get one ranking to check if division exists
                    );
                    
                    if (rankingsResponse.isNotEmpty) {
                      print('🔍 Found rankings for division ID: $divisionId');
                      final ranking = rankingsResponse[0];
                      
                      if (ranking.containsKey('division') && ranking['division'] != null) {
                        final division = ranking['division'];
                        // Create a unique key for the division
                        final divisionKey = '${division['id']}_${division['name']}';
                        if (!uniqueDivisions.any((d) => '${d['id']}_${d['name']}' == divisionKey)) {
                          uniqueDivisions.add(division);
                          print('  - Found division: ${division['name']} (ID: ${division['id']})');
                        }
                      }
                    }
                  } catch (e) {
                    // Division doesn't exist, continue to next
                    print('🔍 Division ID $divisionId not found, continuing...');
                  }
                }
                
                if (uniqueDivisions.isNotEmpty) {
                  divisionsData = uniqueDivisions.toList();
                  print('🔍 Found ${uniqueDivisions.length} total divisions from rankings data');
                } else {
                  print('🔍 No divisions found in rankings data, creating default division structure');
                  divisionsData = [{
                    'id': 1,
                    'name': 'Main',
                    'order': 1,
                  }];
                }
              } catch (rankingsError) {
                print('🔍 Rankings endpoint failed: $rankingsError, creating default division structure');
                divisionsData = [{
                  'id': 1,
                  'name': 'Main',
                  'order': 1,
                }];
              }
            }
          } catch (divisionError) {
            print('🔍 Division endpoint failed: $divisionError, creating default division structure');
            // Create a default "main" division for events without explicit divisions
            divisionsData = [{
              'id': 1,
              'name': 'Main',
              'order': 1,
            }];
          }
        }
      }
      
      final divisions = divisionsData is List ? divisionsData : <dynamic>[];
      
      print('Event Details API returned ${divisions.length} divisions');
      if (divisions.isNotEmpty) {
        for (final division in divisions) {
          print('  - Division: ${division['name'] ?? 'Unknown'} (ID: ${division['id']})');
        }
      }
      print('=== End Event Details Debug ===');
      
      return {
        'divisions': divisions,
        'event': eventData,
      };
    } catch (e) {
      print('Event Details API failed: $e');
      print('=== End Event Details Debug ===');
      return {
        'divisions': <dynamic>[],
        'event': {},
      };
    }
  }

  // Get team rankings for a specific division (like VRC RoboScout)
  static Future<List<dynamic>> getEventDivisionRankings({
    required int eventId,
    required int divisionId,
    int page = 1,
  }) async {
    print('=== Event Division Rankings Debug ===');
    print('Event ID: $eventId, Division ID: $divisionId');
    
    List<dynamic> allRankings = [];
    int currentPage = 1;
    bool hasMorePages = true;
    
    while (hasMorePages) {
      final params = {
        'page': currentPage,
        'per_page': ApiConfig.defaultPageSize,
      };
      
      try {
        final data = await roboteventsRequest(
          requestUrl: '/events/$eventId/divisions/$divisionId/rankings',
          params: params,
        );
        
        print('Page $currentPage: Event Division Rankings API returned ${data.length} rankings for division $divisionId');
        
        // Debug: Print sample ranking data to understand structure
        if (data.isNotEmpty && currentPage == 1) {
          print('🔍 Sample ranking data structure:');
          print('  Keys: ${data[0].keys.toList()}');
          print('  Sample ranking: ${data[0]}');
        }
        
        allRankings.addAll(data);
        
        // Check if we've reached the end (less than max page size means no more pages)
        if (data.length < ApiConfig.defaultPageSize) {
          hasMorePages = false;
        } else {
          currentPage++;
        }
        
      } catch (e) {
        print('❌ Division rankings API failed: $e');
        hasMorePages = false;
      }
    }
    
    print('Total Event Division Rankings API returned ${allRankings.length} rankings for division $divisionId');
    print('=== End Event Division Rankings Debug ===');
    
    return allRankings;
  }

  // Legacy method for backward compatibility
  static Future<List<dynamic>> getEventDivisions({
    required int eventId,
    int page = 1,
  }) async {
    final eventDetails = await getEventDetails(eventId: eventId);
    final divisions = eventDetails['divisions'];
    return divisions is List ? divisions : <dynamic>[];
  }

  // Update season IDs dynamically
  static Future<void> updateSeasonIds() async {
    await ApiConfig.generateSeasonIdMap();
  }

  // Fallback API-only search method
  static Future<List<Event>> _fallbackApiSearch({
    String? query,
    int? seasonId,
    int? levelClass,
    List<String>? levels,
    int page = 1,
  }) async {
    print('=== Fallback API Search ===');
    
    final params = ApiConfig.getEventSearchParams(
      query: query,
      seasonId: seasonId,
      levelClass: levelClass,
      levels: levels,
      page: page,
    );
    
    print('🔍 Fallback API URL: ${ApiConfig.robotEventsBaseUrl}/events?${_buildQueryString(params)}');
    
    final data = await roboteventsRequest(
      requestUrl: '/events',
      params: params,
    );
    
    final events = <Event>[];
    for (final eventData in data) {
      try {
        events.add(Event.fromJson(eventData));
      } catch (e) {
        print('Error parsing event: $e');
      }
    }
    
    print('Fallback API search found ${events.length} events');
    return events;
  }

  // Get team by number
  static Future<Team?> getTeamByNumber(String teamNumber) async {
    try {
      final response = await roboteventsRequest(
        requestUrl: '/teams',
        params: {'number': teamNumber},
      );
      
      if (response.isEmpty) return null;
      
      // Find the team with exact number match
      for (final teamData in response) {
        if (teamData['name'] == teamNumber) {
          return Team.fromJson(teamData);
        }
      }
      return null;
    } catch (e) {
      print('Error getting team by number: $e');
      return null;
    }
  }

  // Get event by SKU
  static Future<Map<String, dynamic>?> getEventBySku(String eventSku) async {
    try {
      final response = await roboteventsRequest(
        requestUrl: '/events',
        params: {'sku': eventSku},
      );
      
      if (response.isEmpty) return null;
      
      // Find the event with exact SKU match
      for (final eventData in response) {
        if (eventData['sku'] == eventSku) {
          return eventData;
        }
      }
      return null;
    } catch (e) {
      print('Error getting event by SKU: $e');
      return null;
    }
  }
} 