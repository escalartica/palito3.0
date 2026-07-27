class UserProfile {
  final String uid;
  final String displayName;
  final int gamerPoints;
  final int decisions;
  final int streak;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.gamerPoints,
    required this.decisions,
    required this.streak,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] ?? 'Usuario',
      gamerPoints: data['gamerPoints'] ?? data['score'] ?? 0,
      decisions: data['decisions'] ?? data['streak'] ?? 0,
      streak: data['streak'] ?? 0,
    );
  }
}