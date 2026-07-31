class UserProfile {
  final String uid;
  final String displayName;
  final int gamerPoints;
  final int decisions;
  final int streak;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.gamerPoints,
    required this.decisions,
    required this.streak,
  });

  // ==========================================================================
  // CONVERSIÓN SEGURA A INT
  // ==========================================================================

  static int _parseInt(
    dynamic value, {
    int fallback = 0,
  }) {
    if (value == null) {
      return fallback;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final String cleanValue =
          value.replaceAll(
        RegExp(r'[^0-9-]'),
        '',
      );

      if (cleanValue.isEmpty) {
        return fallback;
      }

      return int.tryParse(
            cleanValue,
          ) ??
          fallback;
    }

    return fallback;
  }

  // ==========================================================================
  // FROM MAP
  // ==========================================================================

  factory UserProfile.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    return UserProfile(
      uid: uid,
      displayName:
          data['displayName']?.toString() ??
              data['name']?.toString() ??
              'Usuario',
      gamerPoints: _parseInt(
        data['gamerPoints'] ??
            data['total_score'] ??
            data['score'] ??
            data['points'],
      ),
      decisions: _parseInt(
        data['decisions'] ??
            data['totalDecisions'] ??
            data['total_decisions'],
      ),
      streak: _parseInt(
        data['streak'] ??
            data['decisions_streak'],
      ),
    );
  }

  // ==========================================================================
  // TO MAP
  // ==========================================================================

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'gamerPoints': gamerPoints,
      'decisions': decisions,
      'streak': streak,
    };
  }

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

  UserProfile copyWith({
    String? uid,
    String? displayName,
    int? gamerPoints,
    int? decisions,
    int? streak,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName:
          displayName ?? this.displayName,
      gamerPoints:
          gamerPoints ?? this.gamerPoints,
      decisions:
          decisions ?? this.decisions,
      streak:
          streak ?? this.streak,
    );
  }

  @override
  String toString() {
    return 'UserProfile('
        'uid: $uid, '
        'displayName: $displayName, '
        'gamerPoints: $gamerPoints, '
        'decisions: $decisions, '
        'streak: $streak'
        ')';
  }
}