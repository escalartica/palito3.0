import 'package:flutter_test/flutter_test.dart';

import 'package:palito_3_0/core/services/gamer_firestore_service.dart';

/// Cubre GamerStats.fromMainStats tras el paso de "eme"/"ceh" fijos a un
/// mapa `players` indexado por uid con cualquier número de miembros — el
/// cambio central de la Fase A del rediseño multi-tenant.
void main() {
  group('GamerStats.fromMainStats', () {
    test('un único miembro produce un solo player y un team idéntico', () {
      final stats = GamerStats.fromMainStats(
        {
          'players': {
            'uid-1': {
              'displayName': 'Ana',
              'gamerPoints': 10,
              'decisions': 2,
              'streak': 1,
              'unlockedChallenges': ['reto-1'],
            },
          },
        },
        currentUid: 'uid-1',
      );

      expect(stats.players.length, 1);
      expect(stats.forUid('uid-1').gamerPoints, 10);
      expect(stats.team.gamerPoints, 10);
      expect(stats.team.decisions, 2);
      expect(stats.team.unlockedChallenges, ['reto-1']);
    });

    test('dos miembros (el caso actual) se agregan correctamente en team',
        () {
      final stats = GamerStats.fromMainStats(
        {
          'players': {
            'uid-eme': {'gamerPoints': 30, 'decisions': 5, 'streak': 2},
            'uid-ceh': {'gamerPoints': 12, 'decisions': 3, 'streak': 0},
          },
        },
        currentUid: 'uid-eme',
      );

      expect(stats.players.length, 2);
      expect(stats.forUid('uid-eme').gamerPoints, 30);
      expect(stats.forUid('uid-ceh').gamerPoints, 12);
      expect(stats.team.gamerPoints, 42);
      expect(stats.team.decisions, 8);
      expect(stats.team.streak, 2);
    });

    test('tres o más miembros también se agregan sin asumir un tamaño fijo',
        () {
      final stats = GamerStats.fromMainStats(
        {
          'players': {
            'uid-1': {'gamerPoints': 10, 'decisions': 1, 'streak': 0},
            'uid-2': {'gamerPoints': 20, 'decisions': 2, 'streak': 0},
            'uid-3': {'gamerPoints': 30, 'decisions': 3, 'streak': 0},
            'uid-4': {'gamerPoints': 40, 'decisions': 4, 'streak': 0},
          },
        },
        currentUid: 'uid-1',
      );

      expect(stats.players.length, 4);
      expect(stats.team.gamerPoints, 100);
      expect(stats.team.decisions, 10);
    });

    test('un uid sin entrada propia devuelve estadísticas vacías, no un '
        'error', () {
      final stats = GamerStats.fromMainStats(
        {
          'players': {
            'uid-1': {'gamerPoints': 10, 'decisions': 1, 'streak': 0},
          },
        },
        currentUid: 'uid-1',
      );

      final missing = stats.forUid('uid-nuevo-sin-datos');
      expect(missing.gamerPoints, 0);
      expect(missing.uid, 'uid-nuevo-sin-datos');
    });

    test('documento legacy sin mapa de jugadores se asigna al uid actual',
        () {
      final stats = GamerStats.fromMainStats(
        {
          'gamerPoints': 7,
          'decisions': 1,
          'streak': 1,
        },
        currentUid: 'uid-legacy',
      );

      expect(stats.players.length, 1);
      expect(stats.forUid('uid-legacy').gamerPoints, 7);
      expect(stats.team.gamerPoints, 7);
    });

    test('GamerStats.empty sin currentUid no tiene ningún player', () {
      final stats = GamerStats.empty();
      expect(stats.players, isEmpty);
      expect(stats.team.gamerPoints, 0);
    });
  });
}
