import 'package:flutter/material.dart';

import '../../../core/theme/tokens/app_colors.dart';

/// Contenido estático de Zona Gamer: logros desbloqueables y retos de
/// "Juicio Picante". Extraído de gamer_page.dart.
///
/// Se exponen como funciones que construyen una lista nueva en cada
/// llamada (en vez de listas `const`/`final` compartidas a nivel de
/// biblioteca) a propósito: `_GamerPageState` muta estos datos en tiempo
/// de ejecución (marca logros como `unlocked` y añade retos personalizados
/// con `_palitoChallenges.add(...)`), así que cada instancia de la página
/// necesita su propia copia independiente. Compartir una única lista/mapa
/// entre instancias filtraría el estado desbloqueado o los retos añadidos
/// de una sesión a la siguiente, y en el caso de los logros (que son
/// `Map`s) un literal `const` sería además inmutable y lanzaría en tiempo
/// de ejecución al intentar marcarlo como desbloqueado.
/// Los logros de la mesa.
///
/// Eran tres, con colores de la paleta de Material (`Colors.amber`,
/// `Colors.deepOrange`, `Colors.purple`) que no salen de ningún sitio de la
/// marca — el morado del panel era el color más saturado de toda la app y no
/// significaba nada. Ahora son siete y usan los tres colores de Palito.
///
/// Siete y no tres porque tres se agotan en una cena: con dos conseguidos y
/// uno bloqueado no queda nada por lo que volver. La escalera va de "esto lo
/// consigues en el primer giro" a "esto es una sobremesa larga de verdad",
/// que es lo que hace que la siguiente tirada apetezca.
///
/// `desc` describe exactamente lo que comprueba
/// `GamerGameLogic.achievementProgress`. No es un detalle de estilo: "Alma de
/// la Mesa · Interactuar con todos los comensales" estaba implementado como
/// "cinco decisiones", así que se desbloqueaba sin haber interactuado con
/// nadie más. Un logro que miente deja de ser un premio.
List<Map<String, dynamic>> buildGamerAchievements() => [
  {
    'id': 'first_spin',
    'title': 'Se abre la veda',
    'desc': 'Girar la ruleta por primera vez.',
    'icon': Icons.celebration_rounded,
    'color': AppColors.primary,
    'unlocked': false,
  },
  {
    'id': 'soul_table',
    'title': 'Alma de la mesa',
    'desc': 'Que a la ruleta le toque todo el mundo al menos una vez.',
    'icon': Icons.groups_rounded,
    'color': AppColors.accent,
    'unlocked': false,
  },
  {
    'id': 'spicy_streak',
    'title': 'Mesa en racha',
    'desc': 'Llegar a 10 decisiones en la misma sesión.',
    'icon': Icons.local_fire_department_rounded,
    'color': AppColors.accent,
    'unlocked': false,
  },
  {
    'id': 'king_flavor',
    'title': 'Rey del sabor',
    'desc': 'Que alguien alcance los 40 puntos.',
    'icon': Icons.workspace_premium_rounded,
    'color': AppColors.primary,
    'unlocked': false,
  },
  {
    'id': 'full_table',
    'title': 'Mesa llena',
    'desc': 'Sentar a cinco comensales a la vez.',
    'icon': Icons.table_restaurant_rounded,
    'color': AppColors.textPrimary,
    'unlocked': false,
  },
  {
    'id': 'medal_hunter',
    'title': 'Cazamedallas',
    'desc': 'Que alguien reúna cinco medallas del Juicio Picante.',
    'icon': Icons.military_tech_rounded,
    'color': AppColors.primary,
    'unlocked': false,
  },
  {
    'id': 'marathon',
    'title': 'Sobremesa larga',
    'desc': 'Aguantar 25 decisiones sin levantarse de la mesa.',
    'icon': Icons.nightlight_round,
    'color': AppColors.textPrimary,
    'unlocked': false,
  },
];

List<String> buildPalitoChallenges() => [
  '🏆 ¡Pide un plato sorpresa!',
  '💸 ¡Toca pagar la primera ronda de bebidas de toda la mesa!',
  '🍰 ¡Elige el postre a ciegas sin mirar la carta y acierta los ingredientes!',
  '🔍 ¡Haz una cata técnica obligatoria al plato del compañero de al lado!',
  '🎙️ ¡Inaugura el banquete haciendo un brindis épico dedicado a Palito!',
  '🌶️ ¡Prueba el bocado más picante o exótico disponible en la comanda!',
  '🥔 ¡Encuentra la mejor patata de toda la mesa y proclámala oficialmente!',
  '🕵️ ¡Adivina el ingrediente secreto de un plato sin preguntar a nadie!',
  '🤫 ¡Elige un plato para compartir sin decirle a nadie qué es!',
  '📸 ¡Haz la foto gastronómica más artística de la noche!',
  '👃 ¡Huele un plato con los ojos cerrados e intenta adivinar qué lleva!',
  '🔄 ¡Intercambia tu plato con alguien durante un bocado!',
  '🎯 ¡Pide algo que jamás hayas probado antes!',
  '🧠 ¡Describe tu plato sin mencionar ninguno de sus ingredientes!',
  '🎤 ¡Presenta el siguiente plato como si fueras el chef de un restaurante Michelin!',
  '🧂 ¡Adivina si el plato necesita más sal antes de probarlo!',
  '🗺️ ¡Busca en el menú un plato típico de una región que nunca hayas visitado!',
  '💎 ¡Declara cuál es el bocado más valioso de la mesa y explica por qué!',
  '🔥 ¡Encuentra el plato con más personalidad de toda la comanda!',
  '❤️ ¡Regala tu mejor bocado a la persona que elijas!',
  '🎭 ¡Describe tu plato usando solo tres palabras dramáticas!',
  '📖 ¡Inventa una historia de 20 segundos sobre el origen de tu plato!',
  '🧐 ¡Analiza un plato como si fueras un detective buscando pistas!',
  '🥇 ¡Elige al campeón absoluto de la mesa y corona tu Plato de la Noche!',
  '🎰 ¡Deja que Palito decida tu próximo bocado!',
  '🚨 ¡ALERTA PALITO! Tienes que probar el plato que menos te apetezca!',
];
