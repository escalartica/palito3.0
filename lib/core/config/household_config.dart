/// Identificador fijo y compartido del "hogar" Palito.
///
/// Cada dispositivo se autentica con una sesión anónima de Firebase
/// distinta (un UID diferente por instalación), pero TODOS los datos de la
/// app (recuerdos, estadísticas Gamer) se guardan y leen bajo este mismo
/// identificador — así Eme y CeH ven exactamente los mismos datos sin
/// importar en qué iPhone estén.
///
/// La autenticación anónima sigue siendo necesaria (Firestore exige
/// `request.auth != null`), pero deja de usarse para particionar los
/// datos por dispositivo.
const String kHouseholdId = 'palito-hogar';
