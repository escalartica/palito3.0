/// ===========================================================================
/// POLÍTICA DE INVITACIONES
/// ===========================================================================
///
/// Todo lo que se puede decidir sobre un código de invitación SIN hablar con
/// Firestore vive aquí: cuántos usos tiene, cuándo deja de merecer la pena
/// reutilizarlo, cómo se lee en pantalla y cómo se rescata de un mensaje
/// pegado desde WhatsApp.
///
/// POR QUÉ EXISTE. La app creaba un código **de un solo uso** y, además, uno
/// NUEVO cada vez que alguien abría la pantalla de invitar. Las consecuencias
/// eran las que se veían desde fuera:
///
///   1. Invitar a tres personas era imposible de la forma obvia. Pegabas el
///      código en el grupo de WhatsApp, el primero que lo tocaba lo gastaba y
///      los otros dos recibían "Ese código ya se ha usado". Quien invitaba no
///      tenía forma de saber por qué.
///   2. Cada visita a la pantalla dejaba un código vivo más, y no había
///      ninguna pantalla para verlos ni para anularlos. Llaves tiradas por el
///      suelo durante una semana.
///
/// Las reglas del servidor ya permitían hasta 20 usos por código
/// (`firestore.rules`, `invites/{code}`): el límite de uno era una decisión
/// del cliente, no una restricción real.
///
/// Se separa en su propio archivo porque estas decisiones se pueden PROBAR
/// —y de hecho se prueban, en `test/invite_policy_test.dart`— sin arrancar
/// Firebase ni Flutter.
/// ===========================================================================
library;

/// Una invitación viva, reducida a lo que hace falta para decidir qué hacer
/// con ella. Deliberadamente sin nada de Firestore dentro.
class InviteLife {
  const InviteLife({
    required this.code,
    required this.usesLeft,
    required this.expiresAt,
  });

  final String code;

  /// Cuántas personas más pueden entrar con este código.
  final int usesLeft;

  final DateTime expiresAt;
}

abstract final class InvitePolicy {
  /// Longitud del código. Fuente única: `HouseholdService` lo usa para
  /// generarlos y el formulario de "Entrar con un código" para limitar el
  /// campo.
  static const int codeLength = 8;

  /// Alfabeto sin O/0/I/1: son los pares que más se confunden al leer un
  /// código de una captura de pantalla o al dictarlo por teléfono.
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Usos por código. Diez cubre de sobra el caso real (una pareja, una
  /// cuadrilla, una familia) sin acercarse al tope de 20 que imponen las
  /// reglas del servidor.
  static const int defaultMaxUses = 10;

  static const Duration defaultValidFor = Duration(days: 7);

  /// Por debajo de esto no se reutiliza un código: enseñar uno que caduca en
  /// dos horas es peor que dar uno nuevo, porque quien lo recibe puede abrir
  /// el mensaje mañana.
  static const Duration minUsefulLife = Duration(hours: 12);

  static bool isWellFormedCode(String candidate) {
    if (candidate.length != codeLength) return false;
    for (int i = 0; i < candidate.length; i++) {
      if (!alphabet.contains(candidate[i])) return false;
    }
    return true;
  }

  static bool isReusable(InviteLife invite, DateTime now) {
    return invite.usesLeft > 0 &&
        invite.expiresAt.isAfter(now.add(minUsefulLife));
  }

  /// De todas las invitaciones vivas de un grupo, la que conviene volver a
  /// enseñar: primero la que más usos le quedan (para que quepa el grupo
  /// entero), y a igualdad de usos, la que más tarda en caducar.
  static InviteLife? pickReusable(List<InviteLife> invites, DateTime now) {
    final List<InviteLife> usable = invites
        .where((InviteLife i) => isReusable(i, now))
        .toList()
      ..sort((InviteLife a, InviteLife b) {
        final int byUses = b.usesLeft.compareTo(a.usesLeft);
        if (byUses != 0) return byUses;
        return b.expiresAt.compareTo(a.expiresAt);
      });

    return usable.isEmpty ? null : usable.first;
  }

  /// La línea que se pinta debajo del código. Dice las dos únicas cosas que
  /// quien invita necesita saber y que antes no aparecían por ninguna parte:
  /// a cuánta gente le sirve y hasta cuándo.
  static String describe(InviteLife invite, DateTime now) {
    final String people = switch (invite.usesLeft) {
      <= 0 => 'Ya no le quedan usos',
      1 => 'Vale para 1 persona más',
      _ => 'Vale para ${invite.usesLeft} personas más',
    };

    return '$people · ${_expiry(invite.expiresAt, now)}';
  }

  static String _expiry(DateTime expiresAt, DateTime now) {
    final Duration left = expiresAt.difference(now);

    if (left.isNegative) return 'ya ha caducado';
    if (left.inMinutes < 60) return 'caduca en menos de una hora';
    if (left.inHours < 24) {
      return 'caduca en ${left.inHours} ${left.inHours == 1 ? "hora" : "horas"}';
    }

    final int days = left.inDays;
    return days == 1 ? 'caduca mañana' : 'caduca en $days días';
  }

  /// Rescata un código de lo que haya en el portapapeles.
  ///
  /// Quien recibe la invitación tiene el código copiado —entero o dentro del
  /// mensaje completo— y aun así estaba obligado a teclear ocho caracteres a
  /// mano. Esto es lo que permite el botón "Pegar".
  ///
  /// El mensaje completo se escanea SOLO a partir de la palabra "código",
  /// porque el propio texto de la invitación contiene palabras de ocho letras
  /// que son códigos perfectamente válidos —"DESCARGA", sin ir más lejos—.
  /// Sin ancla, el botón pegaría una palabra cualquiera y quien la recibe
  /// vería "Ese código no existe" sin entender por qué.
  ///
  /// Por eso solo hay dos casos aceptados: o el portapapeles es el código
  /// entero, o contiene la palabra "código" y el código va detrás. Cualquier
  /// otra cosa devuelve null y el botón lo dice, en vez de rellenar el campo
  /// con una palabra suelta.
  static String? codeFromSharedText(String? raw) {
    if (raw == null) return null;

    final String upper = raw.trim().toUpperCase();
    if (upper.isEmpty) return null;

    // 1) El portapapeles ES el código.
    if (isWellFormedCode(upper)) return upper;

    // 2) Es el mensaje completo. "CÓDIGO" en mayúsculas conserva la tilde,
    //    así que el ancla se busca por el trozo sin acentos.
    final int marker = upper.indexOf('DIGO');
    if (marker == -1) return null;

    for (final String token
        in upper.substring(marker + 'DIGO'.length).split(RegExp('[^A-Z0-9]+'))) {
      if (isWellFormedCode(token)) return token;
    }

    return null;
  }
}
