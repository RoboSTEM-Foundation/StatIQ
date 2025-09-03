// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Team _$TeamFromJson(Map<String, dynamic> json) => Team(
      id: (json['id'] as num?)?.toInt() ?? 0,
      number: json['number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      robotName: json['robotName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
      country: json['country'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      registered: json['registered'] as bool? ?? false,
      eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
      awards: (json['awards'] as List<dynamic>?)
              ?.map((e) => Award.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => Event.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'name': instance.name,
      'organization': instance.organization,
      'robotName': instance.robotName,
      'city': instance.city,
      'region': instance.region,
      'country': instance.country,
      'grade': instance.grade,
      'registered': instance.registered,
      'eventCount': instance.eventCount,
      'awards': instance.awards,
      'events': instance.events,
    };

Award _$AwardFromJson(Map<String, dynamic> json) => Award(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      order: (json['order'] as num?)?.toInt() ?? 0,
      qualifications: (json['qualifications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      individualWinners: (json['individualWinners'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$AwardToJson(Award instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'order': instance.order,
      'qualifications': instance.qualifications,
      'individualWinners': instance.individualWinners,
    };

Division _$DivisionFromJson(Map<String, dynamic> json) => Division(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );

Map<String, dynamic> _$DivisionToJson(Division instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };

Match _$MatchFromJson(Map<String, dynamic> json) => Match(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      started: json['started'] == null
          ? null
          : DateTime.parse(json['started'] as String),
      scheduled: json['scheduled'] == null
          ? null
          : DateTime.parse(json['scheduled'] as String),
      field: (json['field'] as num?)?.toInt() ?? 0,
      instance: (json['instance'] as num?)?.toInt() ?? 0,
      tournamentLevel: (json['tournamentLevel'] as num?)?.toInt() ?? 0,
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

Map<String, dynamic> _$MatchToJson(Match instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'started': instance.started?.toIso8601String(),
      'scheduled': instance.scheduled?.toIso8601String(),
      'field': instance.field,
      'instance': instance.instance,
      'tournamentLevel': instance.tournamentLevel,
      'alliances': instance.alliances,
      'redScore': instance.redScore,
      'blueScore': instance.blueScore,
    };

MatchTeam _$MatchTeamFromJson(Map<String, dynamic> json) => MatchTeam(
      color: json['color'] as String? ?? '',
      teams: (json['teams'] as List<dynamic>?)
              ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      score: (json['score'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MatchTeamToJson(MatchTeam instance) => <String, dynamic>{
      'color': instance.color,
      'teams': instance.teams,
      'score': instance.score,
    };

MatchScore _$MatchScoreFromJson(Map<String, dynamic> json) => MatchScore(
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      autonomousPoints: (json['autonomousPoints'] as num?)?.toInt() ?? 0,
      driverControlPoints: (json['driverControlPoints'] as num?)?.toInt() ?? 0,
      gameSpecific: json['gameSpecific'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$MatchScoreToJson(MatchScore instance) =>
    <String, dynamic>{
      'totalPoints': instance.totalPoints,
      'autonomousPoints': instance.autonomousPoints,
      'driverControlPoints': instance.driverControlPoints,
      'gameSpecific': instance.gameSpecific,
    };

TeamRanking _$TeamRankingFromJson(Map<String, dynamic> json) => TeamRanking(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      team: Team.fromJson(json['team'] as Map<String, dynamic>),
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      ties: (json['ties'] as num?)?.toInt() ?? 0,
      wp: (json['wp'] as num?)?.toInt() ?? 0,
      ap: (json['ap'] as num?)?.toInt() ?? 0,
      sp: (json['sp'] as num?)?.toInt() ?? 0,
      ccwm: (json['ccwm'] as num?)?.toDouble() ?? 0.0,
      opr: (json['opr'] as num?)?.toDouble() ?? 0.0,
      dpr: (json['dpr'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$TeamRankingToJson(TeamRanking instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'team': instance.team,
      'wins': instance.wins,
      'losses': instance.losses,
      'ties': instance.ties,
      'wp': instance.wp,
      'ap': instance.ap,
      'sp': instance.sp,
      'ccwm': instance.ccwm,
      'opr': instance.opr,
      'dpr': instance.dpr,
    };

TeamSkillsRanking _$TeamSkillsRankingFromJson(Map<String, dynamic> json) =>
    TeamSkillsRanking(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      team: Team.fromJson(json['team'] as Map<String, dynamic>),
      driverSkills: (json['driverSkills'] as num?)?.toInt() ?? 0,
      programmingSkills: (json['programmingSkills'] as num?)?.toInt() ?? 0,
      combinedSkills: (json['combinedSkills'] as num?)?.toInt() ?? 0,
      maxDriver: (json['maxDriver'] as num?)?.toInt() ?? 0,
      maxProgramming: (json['maxProgramming'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as List<dynamic>?)
              ?.map((e) => SkillsRun.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TeamSkillsRankingToJson(TeamSkillsRanking instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'team': instance.team,
      'driverSkills': instance.driverSkills,
      'programmingSkills': instance.programmingSkills,
      'combinedSkills': instance.combinedSkills,
      'maxDriver': instance.maxDriver,
      'maxProgramming': instance.maxProgramming,
      'attempts': instance.attempts,
    };

SkillsRun _$SkillsRunFromJson(Map<String, dynamic> json) => SkillsRun(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      created: json['created'] == null
          ? null
          : DateTime.parse(json['created'] as String),
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SkillsRunToJson(SkillsRun instance) => <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'score': instance.score,
      'created': instance.created?.toIso8601String(),
      'rank': instance.rank,
    };

MixAndMatchScore _$MixAndMatchScoreFromJson(Map<String, dynamic> json) =>
    MixAndMatchScore(
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      autonomousPoints: (json['autonomousPoints'] as num?)?.toInt() ?? 0,
      driverControlPoints: (json['driverControlPoints'] as num?)?.toInt() ?? 0,
      colorsInGoal: (json['colorsInGoal'] as num?)?.toInt() ?? 0,
      ballsInHighGoal: (json['ballsInHighGoal'] as num?)?.toInt() ?? 0,
      ballsInLowGoal: (json['ballsInLowGoal'] as num?)?.toInt() ?? 0,
      ballsCleared: (json['ballsCleared'] as num?)?.toInt() ?? 0,
      platformPoints: (json['platformPoints'] as num?)?.toInt() ?? 0,
      hangingPoints: (json['hangingPoints'] as num?)?.toInt() ?? 0,
      robotParked: json['robotParked'] as bool? ?? false,
    );

Map<String, dynamic> _$MixAndMatchScoreToJson(MixAndMatchScore instance) =>
    <String, dynamic>{
      'totalPoints': instance.totalPoints,
      'autonomousPoints': instance.autonomousPoints,
      'driverControlPoints': instance.driverControlPoints,
      'colorsInGoal': instance.colorsInGoal,
      'ballsInHighGoal': instance.ballsInHighGoal,
      'ballsInLowGoal': instance.ballsInLowGoal,
      'ballsCleared': instance.ballsCleared,
      'platformPoints': instance.platformPoints,
      'hangingPoints': instance.hangingPoints,
      'robotParked': instance.robotParked,
    };
