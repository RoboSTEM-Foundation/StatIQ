import 'package:stat_iq/utils/logger.dart';

class Event {
  final int id;
  final String sku;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final String location;
  final String city;
  final String region;
  final String country;
  final int? levelClassId;
  final String levelClassName;
  final String level; // API event level (e.g., Signature, World, Other)

  Event({
    required this.id,
    required this.sku,
    required this.name,
    this.start,
    this.end,
    required this.location,
    required this.city,
    required this.region,
    required this.country,
    this.levelClassId,
    required this.levelClassName,
    this.level = '',
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    try {
      // Parse location data
      final locationData = json['location'] as Map<String, dynamic>? ?? {};
      
      return Event(
        id: json['id'] as int? ?? 0,
        sku: json['sku'] as String? ?? '',
        name: json['name'] as String? ?? '',
        start: json['start'] != null ? DateTime.tryParse(json['start']) : null,
        end: json['end'] != null ? DateTime.tryParse(json['end']) : null,
        location: _buildLocationString(locationData),
        city: locationData['city'] as String? ?? '',
        region: locationData['region'] as String? ?? '',
        country: locationData['country'] as String? ?? '',
        levelClassId: json['level_class_id'] as int?,
        levelClassName: json['level_class'] as String? ?? '',
        level: json['level'] as String? ?? '',
      );
    } catch (e) {
      AppLogger.d('Error parsing Event JSON: $e');
      AppLogger.d('JSON data: $json');
      rethrow;
    }
  }

  static String _buildLocationString(Map<String, dynamic> locationData) {
    final parts = <String>[];
    
    if (locationData['venue'] != null && (locationData['venue'] as String).isNotEmpty) {
      parts.add(locationData['venue'] as String);
    }
    if (locationData['city'] != null && (locationData['city'] as String).isNotEmpty) {
      parts.add(locationData['city'] as String);
    }
    if (locationData['region'] != null && (locationData['region'] as String).isNotEmpty) {
      parts.add(locationData['region'] as String);
    }
    if (locationData['country'] != null && (locationData['country'] as String).isNotEmpty) {
      parts.add(locationData['country'] as String);
    }
    
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'location': location,
      'city': city,
      'region': region,
      'country': country,
      'level_class_id': levelClassId,
      'level_class': levelClassName,
      'level': level,
    };
  }

  @override
  String toString() {
    return 'Event(id: $id, name: $name, sku: $sku, location: $location)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 