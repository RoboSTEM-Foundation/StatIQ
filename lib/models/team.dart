import 'package:json_annotation/json_annotation.dart';
import 'event.dart';

part 'team.g.dart';

@JsonSerializable()
class Team {
  final int id;
  final String number;
  final String name;
  final String organization;
  final String robotName;
  final String city;
  final String region;
  final String country;
  final String grade; // "Elementary School", "Middle School"
  final bool registered;
  final int eventCount;
  final List<Award> awards;
  final List<Event> events;

  Team({
    this.id = 0,
    this.number = '',
    this.name = '',
    this.organization = '',
    this.robotName = '',
    this.city = '',
    this.region = '',
    this.country = '',
    this.grade = '',
    this.registered = false,
    this.eventCount = 0,
    this.awards = const [],
    this.events = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    try {
      // Handle location data which might be nested or flat
      final location = json['location'] as Map<String, dynamic>? ?? {};
      
      final teamNumber = json['number'] as String? ?? json['team'] as String? ?? '';
      print('🔍 Team.fromJson Debug: json["number"] = ${json['number']}, json["team"] = ${json['team']}, final number = "$teamNumber"');
      
      return Team(
        id: json['id'] as int? ?? 0,
        number: teamNumber,
        name: json['teamName'] as String? ?? json['team_name'] as String? ?? '',
        organization: json['organization'] as String? ?? '',
        robotName: json['robotName'] as String? ?? json['robot_name'] as String? ?? '',
        city: json['city'] as String? ?? location['city'] as String? ?? '',
        region: json['region'] as String? ?? location['region'] as String? ?? '',
        country: json['country'] as String? ?? location['country'] as String? ?? '',
        grade: json['gradeLevel'] as String? ?? json['grade'] as String? ?? '',
        registered: json['registered'] as bool? ?? false,
        eventCount: json['event_count'] as int? ?? 0,
        awards: (json['awards'] as List<dynamic>?)
            ?.map((e) => Award.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
        events: (json['events'] as List<dynamic>?)
            ?.map((e) => Event.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
      );
    } catch (e) {
      print('Error parsing Team: $e');
      print('JSON: $json');
      // Return a basic team with available info
      return Team(
        id: json['id'] as int? ?? 0,
        number: json['number'] as String? ?? 'Unknown',
        name: json['team_name'] as String? ?? json['name'] as String? ?? '',
      );
    }
  }
  Map<String, dynamic> toJson() => _$TeamToJson(this);

  Team copyWith({
    int? id,
    String? number,
    String? name,
    String? organization,
    String? robotName,
    String? city,
    String? region,
    String? country,
    String? grade,
    bool? registered,
    int? eventCount,
    List<Award>? awards,
    List<Event>? events,
  }) {
    return Team(
      id: id ?? this.id,
      number: number ?? this.number,
      name: name ?? this.name,
      organization: organization ?? this.organization,
      robotName: robotName ?? this.robotName,
      city: city ?? this.city,
      region: region ?? this.region,
      country: country ?? this.country,
      grade: grade ?? this.grade,
      registered: registered ?? this.registered,
      eventCount: eventCount ?? this.eventCount,
      awards: awards ?? this.awards,
      events: events ?? this.events,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          number == other.number;

  @override
  int get hashCode => id.hashCode ^ number.hashCode;

  @override
  String toString() {
    return 'Team{id: $id, number: $number, name: $name, grade: $grade}';
  }
}

@JsonSerializable()
class Award {
  final int id;
  final String title;
  final int order;
  final List<String> qualifications;
  final List<String> individualWinners;

  Award({
    this.id = 0,
    this.title = '',
    this.order = 0,
    this.qualifications = const [],
    this.individualWinners = const [],
  });

  factory Award.fromJson(Map<String, dynamic> json) => _$AwardFromJson(json);
  Map<String, dynamic> toJson() => _$AwardToJson(this);
}

// Event class is now imported from event.dart

@JsonSerializable()
class Division {
  final int id;
  final String name;

  Division({
    this.id = 0,
    this.name = '',
  });

  factory Division.fromJson(Map<String, dynamic> json) => _$DivisionFromJson(json);
  Map<String, dynamic> toJson() => _$DivisionToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Division &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class Match {
  final int id;
  final String name;
  final DateTime? started;
  final DateTime? scheduled;
  final int field;
  final int instance;
  final int tournamentLevel;
  final int? eventId;
  final List<MatchTeam> alliances;
  final MatchScore? redScore;
  final MatchScore? blueScore;

  Match({
    this.id = 0,
    this.name = '',
    this.started,
    this.scheduled,
    this.field = 0,
    this.instance = 0,
    this.tournamentLevel = 0,
    this.eventId,
    this.alliances = const [],
    this.redScore,
    this.blueScore,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    // Handle both string and numeric values for VEX IQ matches
    int parseField(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return Match(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      started: json['started'] == null
          ? null
          : DateTime.parse(json['started'] as String),
      scheduled: json['scheduled'] == null
          ? null
          : DateTime.parse(json['scheduled'] as String),
      field: parseField(json['field']),
      instance: parseField(json['instance']),
      tournamentLevel: parseField(json['tournamentLevel']),
      eventId: json['event'] != null ? (json['event'] is int 
          ? json['event'] as int 
          : (json['event'] is Map 
              ? (json['event']['id'] as num?)?.toInt() 
              : null)) : null,
      alliances: (json['alliances'] as List<dynamic>?)
              ?.map((e) => MatchTeam.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      redScore: json['redScore'] == null
          ? null
          : MatchScore.fromJson(json['redScore'] as Map<String, dynamic>),
      blueScore: json['blueScore'] == null
          ? null
          : MatchScore.fromJson(json['blueScore'] as Map<String, dynamic>),
    );
  }
  Map<String, dynamic> toJson() => _$MatchToJson(this);
}

@JsonSerializable()
class MatchTeam {
  final String color; // "red" or "blue"
  final List<Team> teams;
  final int score;

  MatchTeam({
    this.color = '',
    this.teams = const [],
    this.score = 0,
  });

  factory MatchTeam.fromJson(Map<String, dynamic> json) {
    // Handle VEX IQ match team structure
    List<Team> parseTeams(dynamic teamsData) {
      if (teamsData is! List) return [];
      
      return teamsData.map((teamData) {
        if (teamData is Map<String, dynamic>) {
          // Handle nested team structure from API
          final teamInfo = teamData['team'] as Map<String, dynamic>?;
          if (teamInfo != null) {
            // Create a proper team object from the nested structure
            // VEX IQ specific: team identifier might be in 'name' field instead of 'number'
            final teamNumber = teamInfo['number'] as String? ?? 
                               teamInfo['name'] as String? ?? 
                               teamInfo['code'] as String? ?? '';
            final teamName = teamInfo['team_name'] as String? ?? 
                             (teamInfo['name'] != teamNumber ? teamInfo['name'] as String? : '') ?? '';
            
            return Team(
              id: teamInfo['id'] as int? ?? 0,
              number: teamNumber,
              name: teamName,
              robotName: teamInfo['robot_name'] as String? ?? '',
              organization: teamInfo['organization'] as String? ?? '',
              city: teamInfo['city'] as String? ?? '',
              region: teamInfo['region'] as String? ?? '',
              country: teamInfo['country'] as String? ?? '',
              grade: teamInfo['grade_level'] as String? ?? teamInfo['grade'] as String? ?? '',
              registered: teamData['sitting'] == false,
            );
          }
        }
        // Fallback to direct team parsing
        return Team.fromJson(teamData as Map<String, dynamic>);
      }).toList();
    }
    
    return MatchTeam(
      color: json['color'] as String? ?? '',
      teams: parseTeams(json['teams']),
      score: json['score'] is int 
          ? json['score'] as int
          : int.tryParse(json['score']?.toString() ?? '0') ?? 0,
    );
  }
  Map<String, dynamic> toJson() => _$MatchTeamToJson(this);
}

@JsonSerializable()
class MatchScore {
  final int totalPoints;
  final int autonomousPoints;
  final int driverControlPoints;
  final Map<String, dynamic> gameSpecific;

  MatchScore({
    this.totalPoints = 0,
    this.autonomousPoints = 0,
    this.driverControlPoints = 0,
    this.gameSpecific = const {},
  });

  factory MatchScore.fromJson(Map<String, dynamic> json) => _$MatchScoreFromJson(json);
  Map<String, dynamic> toJson() => _$MatchScoreToJson(this);
}

@JsonSerializable()
class TeamRanking {
  final int rank;
  final Team team;
  final int wins;
  final int losses;
  final int ties;
  final int wp; // Winning percentage
  final int ap; // Autonomous points
  final int sp; // Strength of schedule
  final double ccwm; // Calculated contribution to winning margin
  final double opr; // Offensive power rating
  final double dpr; // Defensive power rating

  TeamRanking({
    this.rank = 0,
    required this.team,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.wp = 0,
    this.ap = 0,
    this.sp = 0,
    this.ccwm = 0.0,
    this.opr = 0.0,
    this.dpr = 0.0,
  });

  factory TeamRanking.fromJson(Map<String, dynamic> json) => _$TeamRankingFromJson(json);
  Map<String, dynamic> toJson() => _$TeamRankingToJson(this);
}

@JsonSerializable()
class TeamSkillsRanking {
  final int rank;
  final Team team;
  final int driverSkills;
  final int programmingSkills;
  final int combinedSkills;
  final int maxDriver;
  final int maxProgramming;
  final List<SkillsRun> attempts;

  TeamSkillsRanking({
    this.rank = 0,
    required this.team,
    this.driverSkills = 0,
    this.programmingSkills = 0,
    this.combinedSkills = 0,
    this.maxDriver = 0,
    this.maxProgramming = 0,
    this.attempts = const [],
  });

  factory TeamSkillsRanking.fromJson(Map<String, dynamic> json) => _$TeamSkillsRankingFromJson(json);
  Map<String, dynamic> toJson() => _$TeamSkillsRankingToJson(this);
}

@JsonSerializable()
class SkillsRun {
  final int id;
  final String type; // "driver" or "programming"
  final int score;
  final DateTime? created;
  final int rank;

  SkillsRun({
    this.id = 0,
    this.type = '',
    this.score = 0,
    this.created,
    this.rank = 0,
  });

  factory SkillsRun.fromJson(Map<String, dynamic> json) => _$SkillsRunFromJson(json);
  Map<String, dynamic> toJson() => _$SkillsRunToJson(this);
}

// Mix and Match specific scoring model
@JsonSerializable()
class MixAndMatchScore {
  final int totalPoints;
  final int autonomousPoints;
  final int driverControlPoints;
  
  // Mix and Match specific scoring elements
  final int colorsInGoal;
  final int ballsInHighGoal;
  final int ballsInLowGoal;
  final int ballsCleared;
  final int platformPoints;
  final int hangingPoints;
  final bool robotParked;

  MixAndMatchScore({
    this.totalPoints = 0,
    this.autonomousPoints = 0,
    this.driverControlPoints = 0,
    this.colorsInGoal = 0,
    this.ballsInHighGoal = 0,
    this.ballsInLowGoal = 0,
    this.ballsCleared = 0,
    this.platformPoints = 0,
    this.hangingPoints = 0,
    this.robotParked = false,
  });

  factory MixAndMatchScore.fromJson(Map<String, dynamic> json) => _$MixAndMatchScoreFromJson(json);
  Map<String, dynamic> toJson() => _$MixAndMatchScoreToJson(this);
} 