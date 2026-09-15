/// Cuánto hace de una fecha, dicho como lo diría alguien.
///
/// «Hace 3 días» se entiende sin restar nada; «14/09/2026» obliga a pensar
/// qué día es hoy. En un diario de comidas el «cuándo» es un dato de primera
/// —¿fui la semana pasada o hace un año?— y hasta ahora no aparecía en
/// ninguna pantalla de la app.
///
/// A partir de un año se da la fecha, porque «hace 14 meses» ya no dice nada.
String relativeDate(DateTime date) {
  final DateTime now = DateTime.now();
  final int days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;

  // Una fecha futura no debería existir, pero existir puede: el reloj del
  // móvil lo pone el usuario. Mejor decir "hoy" que "hace -3 días".
  if (days <= 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  if (days < 7) return 'Hace $days días';
  if (days < 14) return 'Hace una semana';
  if (days < 31) return 'Hace ${days ~/ 7} semanas';
  if (days < 60) return 'Hace un mes';
  if (days < 365) return 'Hace ${days ~/ 30} meses';

  return '${date.day}/${date.month}/${date.year}';
}
